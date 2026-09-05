#!/usr/bin/env python3
"""Mastodon mention listener for the Rails-backed battle game."""

from __future__ import annotations

import json
import logging
import os
import signal
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path
from typing import Any

from dotenv import load_dotenv
from mastodon import Mastodon, StreamListener


load_dotenv(Path(__file__).with_name(".env"))
logging.basicConfig(
    level=os.getenv("GAME_BOT_LOG_LEVEL", "INFO"),
    format="%(asctime)s %(levelname)s %(name)s: %(message)s",
)
LOGGER = logging.getLogger("battle_bot")

BASE_URL = os.environ["MASTODON_BASE_URL"].rstrip("/")
ACCESS_TOKEN = os.environ["MASTODON_ACCESS_TOKEN"]
GAME_API_URL = os.getenv("GAME_API_URL", BASE_URL).rstrip("/")
STREAMING_BASE_URL = os.getenv("MASTODON_STREAMING_BASE_URL", "").rstrip("/")


class RailsGameClient:
    def process(self, status_id: str) -> dict[str, Any]:
        body = json.dumps({"status_id": str(status_id)}).encode("utf-8")
        request = urllib.request.Request(
            f"{GAME_API_URL}/api/v1/game/bot/commands",
            data=body,
            method="POST",
            headers={
                "Authorization": f"Bearer {ACCESS_TOKEN}",
                "Content-Type": "application/json",
                "Accept": "application/json",
            },
        )
        try:
            with urllib.request.urlopen(request, timeout=15) as response:
                return json.load(response)
        except urllib.error.HTTPError as error:
            detail = error.read().decode("utf-8", errors="replace")
            raise RuntimeError(f"Rails API {error.code}: {detail}") from error


class BattleListener(StreamListener):
    def __init__(self, mastodon: Mastodon, game_client: RailsGameClient, bot_id: str):
        self.mastodon = mastodon
        self.game_client = game_client
        self.bot_id = str(bot_id)

    def on_notification(self, notification: dict[str, Any]) -> None:
        if notification.get("type") != "mention":
            return

        status = notification.get("status")
        if not status or str(status["account"]["id"]) == self.bot_id:
            return

        status_id = str(status["id"])
        try:
            result = self.game_client.process(status_id)
            mentions = " ".join(f"@{acct}" for acct in result.get("account_accts", []))
            text = f"{mentions}\n\n{result['text']}" if mentions else result["text"]
            self.mastodon.status_post(
                text,
                in_reply_to_id=result.get("in_reply_to_id", status_id),
                visibility=result.get("visibility", status.get("visibility", "unlisted")),
                idempotency_key=f"game-bot-{status_id}",
            )
            LOGGER.info("Processed status %s", status_id)
        except Exception:
            LOGGER.exception("Failed to process status %s", status_id)


def main() -> int:
    mastodon = Mastodon(access_token=ACCESS_TOKEN, api_base_url=BASE_URL)
    if STREAMING_BASE_URL:
        # Mastodon.py has no public constructor option for deployments whose
        # advertised browser streaming URL is unreachable from this container.
        setattr(mastodon, "_Mastodon__streaming_base", STREAMING_BASE_URL)
    bot = mastodon.account_verify_credentials()
    listener = BattleListener(mastodon, RailsGameClient(), str(bot["id"]))
    LOGGER.info("Battle bot started as @%s", bot["acct"])

    # Recover mentions that arrived while the process was stopped. Rails keeps
    # status IDs idempotent, so already processed notifications are harmless.
    pending_mentions = mastodon.notifications(types=["mention"], limit=40)
    for notification in reversed(pending_mentions):
        listener.on_notification(notification)

    def stop(_signum: int, _frame: Any) -> None:
        LOGGER.info("Battle bot stopping")
        sys.exit(0)

    signal.signal(signal.SIGTERM, stop)
    signal.signal(signal.SIGINT, stop)
    while True:
        try:
            mastodon.stream_user(listener)
        except Exception:
            LOGGER.exception("Streaming connection lost; reconnecting in 5 seconds")
            time.sleep(5)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
