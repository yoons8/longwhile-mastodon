# Battle bot

The bot listens for Mastodon mentions and delegates all game decisions to Rails.

To transfer one owned item, mention the recipient and the bot together and post
`[양도/아이템이름]`. Each sender can complete up to three transfers per day.

```bash
python3 -m venv .venv
.venv/bin/pip install -r battle_bot/requirements.txt
cp battle_bot/.env.example battle_bot/.env
.venv/bin/python battle_bot/bot.py
```

Set `MASTODON_ACCESS_TOKEN` to the token owned by the local `battle_bot` account.
For the local account created with this feature, print or create that token with:

```bash
bin/rails game:bot:token
```

Copy it only into `battle_bot/.env`; that file is ignored by Git. When the bot
runs outside the Mastodon container, use the host URL for `MASTODON_BASE_URL`.
Set `MASTODON_STREAMING_BASE_URL` only when the streaming URL advertised by the
development server is not reachable from the bot container.

If Python venv support is unavailable on the host, use Docker instead:

```bash
docker build -t mastodon-battle-bot battle_bot
docker run --rm --env-file battle_bot/.env --network host mastodon-battle-bot
```

For production, run this process under systemd or a dedicated container with an
automatic restart policy.

The bot records the most recently replied-to mention in `battle_bot/.state.json`.
This ignored local file prevents a restart from replying to the same mention
again. Do not delete it unless you intentionally want the bot to reprocess the
recent mention notifications.
