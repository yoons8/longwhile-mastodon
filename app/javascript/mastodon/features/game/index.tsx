/* eslint-disable react/jsx-no-bind -- Item and panel handlers depend on each rendered record. */
import { useCallback, useEffect, useState } from 'react';

import { Helmet } from 'react-helmet';

import api from 'mastodon/api';
import { Column } from 'mastodon/components/column';
import { ColumnHeader } from 'mastodon/components/column_header';

import './style.scss';

interface GameItem {
  id?: number;
  name: string;
  description: string;
  image: string | null;
  consumable: boolean;
  item_type?: 'battle' | 'roleplay' | 'miscellaneous';
  battle_action?: 'attack' | 'defense' | null;
  dice_count?: number | null;
  dice_sides?: number | null;
  flat_bonus?: number;
  quantity?: number;
  price?: number;
  stock?: number | null;
  sale_price?: number;
}

interface GameShop {
  id: number;
  name: string;
  description: string;
  shop_type: 'normal' | 'secret' | 'event';
  items: GameItem[];
}

interface GameState {
  profile: { currency: number; reputation: number };
  daily_usage: Partial<Record<'shell_game' | 'simon' | 'blackjack', number>>;
  inventory: GameItem[];
  shops: GameShop[];
  blackjack?: BlackjackState | null;
}

interface SimonState {
  token: string;
  round: number;
  sequence: number[];
  success?: boolean;
  complete?: boolean;
  reward?: number;
}

interface BlackjackCard {
  rank: string;
  suit: string;
}

interface BlackjackState {
  token?: string;
  bet: number;
  player_cards: BlackjackCard[];
  dealer_cards: BlackjackCard[];
  player_total: number;
  dealer_total?: number;
  can_hit?: boolean;
  finished?: boolean;
  outcome?: 'win' | 'lose' | 'push';
  message?: string;
  payout?: number;
  currency?: number;
}

type Tab = 'shop' | 'gamble';
type GambleView = 'list' | 'shell' | 'simon' | 'blackjack';

const errorMessage = (error: unknown) => {
  if (typeof error === 'object' && error !== null && 'response' in error) {
    const response = (error as { response?: { data?: { error?: string } } })
      .response;
    if (response?.data?.error) return response.data.error;
  }

  return '요청을 처리하지 못했습니다.';
};

const delay = (milliseconds: number) =>
  new Promise<void>((resolve) => window.setTimeout(resolve, milliseconds));

const isRedSuit = (suit: string) => suit === '♥' || suit === '♦';
const GAME_DAILY_LIMIT = 3;

const battleEffectLabel = (item: GameItem) => {
  const action = item.battle_action === 'defense' ? '방어' : '공격';
  const effects = [];

  if (item.dice_count && item.dice_sides)
    effects.push(`주사위 ${item.dice_count}d${item.dice_sides}`);
  if (item.flat_bonus)
    effects.push(
      `고정 보정 ${item.flat_bonus > 0 ? '+' : ''}${item.flat_bonus}`,
    );

  return `${action} · ${effects.join(' · ') || '보정 없음'}`;
};

const Game: React.FC<{ multiColumn?: boolean }> = ({ multiColumn }) => {
  const [state, setState] = useState<GameState | null>(null);
  const [tab, setTab] = useState<Tab>('shop');
  const [gambleView, setGambleView] = useState<GambleView>('list');
  const [selectedItem, setSelectedItem] = useState<GameItem | null>(null);
  const [message, setMessage] = useState('어서 오세요. 천천히 둘러보세요.');
  const [busy, setBusy] = useState(false);
  const [bet, setBet] = useState(1);
  const [cup, setCup] = useState(1);
  const [shellAnswer, setShellAnswer] = useState<number | null>(null);
  const [shellWon, setShellWon] = useState<boolean | null>(null);
  const [shellShuffling, setShellShuffling] = useState(false);
  const [simon, setSimon] = useState<SimonState | null>(null);
  const [simonInput, setSimonInput] = useState<number[]>([]);
  const [simonActivePanel, setSimonActivePanel] = useState<number | null>(null);
  const [simonCountdown, setSimonCountdown] = useState<number | null>(null);
  const [simonAccepting, setSimonAccepting] = useState(false);
  const [simonMessage, setSimonMessage] = useState('시작 버튼을 누르세요.');
  const [blackjack, setBlackjack] = useState<BlackjackState | null>(null);
  const dailyUsage = state?.daily_usage ?? {};
  const shellRemaining = Math.max(
    0,
    GAME_DAILY_LIMIT - (dailyUsage.shell_game ?? 0),
  );
  const simonRemaining = Math.max(
    0,
    GAME_DAILY_LIMIT - (dailyUsage.simon ?? 0),
  );
  const blackjackRemaining = Math.max(
    0,
    GAME_DAILY_LIMIT - (dailyUsage.blackjack ?? 0),
  );

  const loadState = useCallback(async () => {
    const response = await api().get<GameState>('/game/state');
    setState(response.data);
    if (response.data.blackjack) setBlackjack(response.data.blackjack);
    setSelectedItem(
      (current) =>
        current ??
        response.data.shops[0]?.items[0] ??
        response.data.inventory[0] ??
        null,
    );
  }, []);

  useEffect(() => {
    void loadState().catch((error: unknown) => {
      setMessage(errorMessage(error));
    });
  }, [loadState]);

  const selectItem = useCallback((item: GameItem) => {
    setSelectedItem(item);
    const price = item.price === undefined ? '' : ` · ${item.price} 재화`;
    setMessage(
      `${item.name} — ${item.description || '설명이 없습니다.'}${price}`,
    );
  }, []);

  const openGamble = useCallback(() => {
    setTab('gamble');
    setGambleView('list');
    setSimonAccepting(false);
    setMessage('오늘은 어떤 게임에 도전하시겠습니까?');
  }, []);

  const openGambleGame = useCallback(
    (view: Exclude<GambleView, 'list'>, description: string) => {
      setGambleView(view);
      setShellAnswer(null);
      setShellWon(null);
      setMessage(description);
    },
    [],
  );

  const backToGambleList = useCallback(() => {
    setGambleView('list');
    setSimonAccepting(false);
    setMessage('게임을 선택하세요.');
  }, []);

  const act = useCallback(
    async (
      path: string,
      data: Record<string, unknown>,
      success: (result: Record<string, unknown>) => string,
    ) => {
      if (busy) return;
      setBusy(true);
      try {
        const response = await api().post<Record<string, unknown>>(path, data);
        setMessage(success(response.data));
        await loadState();
      } catch (error) {
        setMessage(errorMessage(error));
      } finally {
        setBusy(false);
      }
    },
    [busy, loadState],
  );

  const playShellGame = useCallback(async () => {
    if (busy || bet <= 0) return;
    setBusy(true);
    setShellShuffling(true);
    setShellAnswer(null);
    setShellWon(null);
    setMessage('컵을 섞고 있습니다…');
    try {
      const response = await api().post<{
        won: boolean;
        answer: number;
        currency_change: number;
      }>('/game/shell_game', { bet, cup });
      await delay(850);
      setShellAnswer(response.data.answer);
      setShellWon(response.data.won);
      setMessage(
        `${response.data.won ? '정답입니다!' : '아쉽군요.'} 공은 ${response.data.answer}번 컵 아래에 있습니다. 재화 ${response.data.currency_change >= 0 ? '+' : ''}${response.data.currency_change}`,
      );
      await loadState();
    } catch (error) {
      setMessage(errorMessage(error));
    } finally {
      setShellShuffling(false);
      setBusy(false);
    }
  }, [bet, busy, cup, loadState]);

  const showSequence = useCallback(async (nextSimon: SimonState) => {
    setSimonAccepting(false);
    setSimonInput([]);
    const reducedMotion = window.matchMedia(
      '(prefers-reduced-motion: reduce)',
    ).matches;
    const countdownDelay = reducedMotion ? 180 : 650;
    const panelDelay = reducedMotion ? 160 : 350;
    const panelGap = reducedMotion ? 80 : 140;

    for (const count of [3, 2, 1]) {
      setSimonCountdown(count);
      setSimonMessage(`${nextSimon.round}라운드 시작 카운트다운 ${count}`);
      await delay(countdownDelay);
    }

    setSimonCountdown(null);
    setSimonMessage(`${nextSimon.round}라운드 · 순서를 기억하세요.`);
    await delay(reducedMotion ? 80 : 260);
    for (const panel of nextSimon.sequence) {
      setSimonActivePanel(panel);
      await delay(panelDelay);
      setSimonActivePanel(null);
      await delay(panelGap);
    }
    setSimonAccepting(true);
    setSimonMessage(`${nextSimon.sequence.length}개를 순서대로 입력하세요.`);
  }, []);

  const startSimon = useCallback(async () => {
    setBusy(true);
    try {
      const response = await api().post<SimonState>('/game/start_simon');
      setSimon(response.data);
      await loadState();
      await showSequence(response.data);
    } catch (error) {
      setSimonMessage(errorMessage(error));
    } finally {
      setBusy(false);
    }
  }, [loadState, showSequence]);

  const submitSimon = useCallback(
    async (current: SimonState, input: number[]) => {
      setSimonAccepting(false);
      try {
        const response = await api().post<SimonState>('/game/submit_simon', {
          token: current.token,
          sequence: input,
        });
        const result = response.data;
        if (!result.success) {
          setSimon(null);
          setSimonMessage('틀렸습니다. 다시 시작해 보세요.');
        } else if (result.complete) {
          setSimon(null);
          setSimonMessage(`성공! ${result.reward ?? 0} 재화를 받았습니다.`);
          await loadState();
        } else {
          setSimon(result);
          await showSequence(result);
        }
      } catch (error) {
        setSimon(null);
        setSimonMessage(errorMessage(error));
      }
    },
    [loadState, showSequence],
  );

  const chooseSimonPanel = useCallback(
    (panel: number) => {
      if (!simon || !simonAccepting) return;
      setSimonActivePanel(panel);
      window.setTimeout(() => {
        setSimonActivePanel(null);
      }, 180);
      const input = [...simonInput, panel];
      setSimonInput(input);
      if (input.length === simon.sequence.length)
        void submitSimon(simon, input);
    },
    [simon, simonAccepting, simonInput, submitSimon],
  );

  const applyBlackjackState = useCallback((nextState: BlackjackState) => {
    setBlackjack(nextState);
    setMessage(
      nextState.finished
        ? (nextState.message ?? '게임이 종료되었습니다.')
        : `현재 합계는 ${nextState.player_total}입니다. 히트 또는 스탠드를 선택하세요.`,
    );
    const currency = nextState.currency;
    if (currency !== undefined) {
      setState((current) =>
        current
          ? {
              ...current,
              profile: { ...current.profile, currency },
            }
          : current,
      );
    }
  }, []);

  const startBlackjack = useCallback(async () => {
    if (busy || bet <= 0) return;

    setBusy(true);
    try {
      const response = await api().post<BlackjackState>(
        '/game/start_blackjack',
        {
          bet,
        },
      );
      applyBlackjackState(response.data);
      await loadState();
    } catch (error) {
      setMessage(errorMessage(error));
    } finally {
      setBusy(false);
    }
  }, [applyBlackjackState, bet, busy, loadState]);

  const playBlackjack = useCallback(
    async (action: 'hit' | 'stand') => {
      if (busy || !blackjack?.token) return;

      setBusy(true);
      try {
        const response = await api().post<BlackjackState>(
          action === 'hit' ? '/game/blackjack_hit' : '/game/blackjack_stand',
          { token: blackjack.token },
        );
        applyBlackjackState(response.data);
      } catch (error) {
        setBlackjack(null);
        setMessage(errorMessage(error));
      } finally {
        setBusy(false);
      }
    },
    [applyBlackjackState, blackjack, busy],
  );

  useEffect(() => {
    const handleKeyDown = (event: KeyboardEvent) => {
      const target = event.target as HTMLElement | null;

      if (target?.matches('input, textarea, select, [contenteditable="true"]'))
        return;

      if (
        gambleView === 'shell' &&
        !busy &&
        event.key >= '1' &&
        event.key <= '3'
      ) {
        setCup(Number(event.key));
        setShellAnswer(null);
        setShellWon(null);
      } else if (event.key >= '1' && event.key <= '4') {
        chooseSimonPanel(Number(event.key) - 1);
      }
    };
    document.addEventListener('keydown', handleKeyDown);
    return () => {
      document.removeEventListener('keydown', handleKeyDown);
    };
  }, [busy, chooseSimonPanel, gambleView]);

  return (
    <Column bindToDocument={!multiColumn} label='게임 상점'>
      <ColumnHeader title='' multiColumn={multiColumn} />
      <div className='scrollable game-page'>
        <section className='game-page__shopkeeper' aria-live='polite'>
          <div className='game-page__portrait' aria-hidden='true'>
            상점주인
          </div>
          <div className='game-page__shopkeeper-main'>
            <div className='game-page__speech'>
              <p>{message}</p>
              <span>
                재화 {state?.profile.currency ?? '—'} · 명성{' '}
                {state?.profile.reputation ?? '—'}
              </span>
            </div>
            <nav className='game-page__tabs' aria-label='게임 메뉴'>
              <button
                type='button'
                disabled={busy}
                onClick={() =>
                  void act('/game/talk', {}, (result) =>
                    String(result.dialogue),
                  )
                }
              >
                대화
              </button>
              <button
                type='button'
                disabled={busy}
                onClick={() =>
                  void act(
                    '/game/vend',
                    {},
                    (result) =>
                      `자판기에서 ${String(result.item)}을(를) 얻었습니다.`,
                  )
                }
              >
                자판기
              </button>
              <button
                type='button'
                className={tab === 'shop' ? 'active' : undefined}
                onClick={() => {
                  setTab('shop');
                  setMessage(
                    '구매 가능한 아이템입니다. 원하는 물건을 선택해 보세요.',
                  );
                }}
              >
                상점
              </button>
              <button
                type='button'
                className={tab === 'gamble' ? 'active' : undefined}
                onClick={openGamble}
              >
                갬블
              </button>
            </nav>
          </div>
        </section>

        <main
          className={
            tab === 'gamble'
              ? 'game-page__content game-page__content--gamble'
              : 'game-page__content'
          }
        >
          {tab === 'shop' ? (
            <>
              {state?.shops.length === 0 && (
                <p className='game-page__empty'>
                  현재 이용 가능한 상점이 없습니다.
                </p>
              )}
              {state?.shops.map((shop) => (
                <section
                  className={`game-page__shop game-page__shop--${shop.shop_type}`}
                  key={shop.id}
                >
                  <header>
                    <strong>{shop.name}</strong>
                    <span>{shop.description}</span>
                  </header>
                  <div className='game-page__item-grid'>
                    {shop.items.length === 0 && (
                      <p className='game-page__empty'>
                        등록된 상점 상품이 없습니다.
                      </p>
                    )}
                    {shop.items.map((item) => (
                      <article
                        className={`game-page__item-card game-page__item-card--shop${selectedItem?.id === item.id ? ' active' : ''}`}
                        key={item.id}
                      >
                        <button
                          type='button'
                          className='game-page__item-select'
                          onClick={() => {
                            selectItem(item);
                          }}
                        >
                          {item.image ? (
                            <img src={item.image} alt='' />
                          ) : (
                            <span className='game-page__mini-placeholder'>
                              아이템
                            </span>
                          )}
                          <strong>{item.name}</strong>
                          {item.item_type === 'battle' && (
                            <span className='game-page__battle-effect'>
                              {battleEffectLabel(item)}
                            </span>
                          )}
                          {item.item_type !== 'battle' && (
                            <span className='game-page__battle-effect'>
                              비전투 아이템
                            </span>
                          )}
                          <span className='game-page__item-price'>
                            {item.price} 재화
                          </span>
                        </button>
                        <div className='game-page__card-actions'>
                          <button
                            type='button'
                            className='game-page__purchase-button'
                            disabled={busy}
                            onClick={() =>
                              void act(
                                '/game/purchase',
                                { game_item_id: item.id },
                                () => `${item.name}을(를) 구매했습니다.`,
                              )
                            }
                          >
                            구매
                          </button>
                        </div>
                      </article>
                    ))}
                  </div>
                </section>
              ))}
              <section className='game-page__shop'>
                <header>
                  <strong>소지품</strong>
                  <span>보유 아이템을 선택해 판매할 수 있습니다.</span>
                </header>
                <div className='game-page__item-grid'>
                  {state?.inventory.length === 0 && (
                    <p className='game-page__empty'>
                      보유한 아이템이 없습니다.
                    </p>
                  )}
                  {state?.inventory.map((item) => (
                    <article
                      className={`game-page__item-card game-page__item-card--inventory${selectedItem?.id === item.id ? ' active' : ''}`}
                      key={item.id}
                    >
                      <button
                        type='button'
                        className='game-page__item-select'
                        onClick={() => {
                          selectItem(item);
                        }}
                      >
                        {item.image ? (
                          <img src={item.image} alt='' />
                        ) : (
                          <span className='game-page__mini-placeholder'>
                            아이템
                          </span>
                        )}
                        <strong>{item.name}</strong>
                        {item.item_type === 'battle' && (
                          <span className='game-page__battle-effect'>
                            {battleEffectLabel(item)}
                          </span>
                        )}
                        <span className='game-page__item-price'>
                          {item.quantity}개 · 판매가 {item.sale_price}
                        </span>
                      </button>
                      <div className='game-page__card-actions'>
                        <button
                          type='button'
                          className='game-page__sell-button'
                          disabled={busy || !item.quantity}
                          onClick={() =>
                            void act(
                              '/game/sell',
                              { game_item_id: item.id, quantity: 1 },
                              () => `${item.name} 1개를 판매했습니다.`,
                            )
                          }
                        >
                          판매
                        </button>
                      </div>
                    </article>
                  ))}
                </div>
              </section>
            </>
          ) : (
            <div className='game-page__games'>
              {gambleView === 'list' && (
                <>
                  <header className='game-page__games-intro'>
                    <span>GAMBLE ROOM</span>
                    <p>게임을 선택하면 규칙과 진행 화면이 열립니다.</p>
                  </header>
                  <div className='game-page__gamble-list'>
                    <button
                      type='button'
                      className='game-page__game-card game-page__game-card--shell'
                      onClick={() => {
                        openGambleGame(
                          'shell',
                          '컵 아래 숨겨진 공의 위치를 맞혀 보세요. 하루에 세 번 도전할 수 있습니다.',
                        );
                      }}
                    >
                      <span className='game-page__game-icon' aria-hidden='true'>
                        <i />
                        <i />
                        <i />
                      </span>
                      <span className='game-page__game-card-copy'>
                        <em>LUCK</em>
                        <strong>야바위</strong>
                        <small>세 개의 컵 중 공이 숨은 곳을 고르세요.</small>
                      </span>
                      <span className='game-page__game-card-footer'>
                        <span>오늘 {shellRemaining}회 남음</span>
                        <strong>
                          게임 시작 <b aria-hidden='true'>→</b>
                        </strong>
                      </span>
                    </button>
                    <button
                      type='button'
                      className='game-page__game-card game-page__game-card--simon'
                      onClick={() => {
                        openGambleGame(
                          'simon',
                          '빛나는 패널의 순서를 기억하고 그대로 입력하세요.',
                        );
                      }}
                    >
                      <span
                        className='game-page__game-icon game-page__game-icon--simon'
                        aria-hidden='true'
                      >
                        <i />
                        <i />
                        <i />
                        <i />
                      </span>
                      <span className='game-page__game-card-copy'>
                        <em>MEMORY</em>
                        <strong>Simon 기억력 게임</strong>
                        <small>빛나는 패널의 순서를 끝까지 기억하세요.</small>
                      </span>
                      <span className='game-page__game-card-footer'>
                        <span>오늘 {simonRemaining}회 · 5라운드 보상</span>
                        <strong>
                          게임 시작 <b aria-hidden='true'>→</b>
                        </strong>
                      </span>
                    </button>
                    <button
                      type='button'
                      className='game-page__game-card game-page__game-card--blackjack'
                      onClick={() => {
                        openGambleGame(
                          'blackjack',
                          '21에 가깝게 만드세요. 딜러보다 높은 숫자가 승리합니다.',
                        );
                      }}
                    >
                      <span
                        className='game-page__game-icon game-page__game-icon--blackjack'
                        aria-hidden='true'
                      >
                        <i>
                          <b>A</b>
                          <em>♠</em>
                        </i>
                        <i>
                          <b>K</b>
                          <em>♥</em>
                        </i>
                      </span>
                      <span className='game-page__game-card-copy'>
                        <em>BLACKJACK</em>
                        <strong>블랙잭</strong>
                        <small>21에 가까워지되, 넘지 마세요.</small>
                      </span>
                      <span className='game-page__game-card-footer'>
                        <span>오늘 {blackjackRemaining}회 · 딜러와 승부</span>
                        <strong>
                          게임 시작 <b aria-hidden='true'>→</b>
                        </strong>
                      </span>
                    </button>
                  </div>
                </>
              )}

              {gambleView === 'shell' && (
                <section className='game-page__game-component game-page__shell-game'>
                  <div className='game-page__game-toolbar'>
                    <header className='game-page__game-header'>
                      <div>
                        <h3>야바위</h3>
                        <p>공이 숨은 컵 하나를 고르세요.</p>
                      </div>
                      <div className='game-page__game-header-actions'>
                        <span className='game-page__game-badge'>
                          오늘 {shellRemaining} / 3회
                        </span>
                        <button
                          type='button'
                          className='game-page__back'
                          disabled={busy}
                          onClick={backToGambleList}
                        >
                          ←
                        </button>
                      </div>
                    </header>
                  </div>
                  <div
                    className={
                      shellShuffling
                        ? 'game-page__shell-stage is-shuffling'
                        : shellAnswer
                          ? 'game-page__shell-stage is-revealed'
                          : 'game-page__shell-stage'
                    }
                  >
                    <div className='game-page__shell-status' aria-live='polite'>
                      {shellShuffling
                        ? '컵을 섞고 있습니다…'
                        : shellAnswer
                          ? `${shellAnswer}번 컵의 공을 공개했습니다.`
                          : '공이 숨은 컵을 선택하세요.'}
                    </div>
                    <div
                      className={
                        shellShuffling
                          ? 'game-page__cups game-page__cups--shuffling'
                          : 'game-page__cups'
                      }
                      aria-label='컵 선택'
                    >
                      {[1, 2, 3].map((number) => (
                        <button
                          type='button'
                          className={
                            cup === number
                              ? 'game-page__cup-choice active'
                              : 'game-page__cup-choice'
                          }
                          disabled={busy}
                          aria-pressed={cup === number}
                          key={number}
                          onClick={() => {
                            setCup(number);
                            setShellAnswer(null);
                            setShellWon(null);
                          }}
                        >
                          <span className='game-page__cup' aria-hidden='true' />
                          <span className='game-page__cup-number'>
                            {number}
                          </span>
                          {shellAnswer === number && (
                            <span className='game-page__ball' aria-label='공'>
                              ●
                            </span>
                          )}
                        </button>
                      ))}
                    </div>
                  </div>
                  {shellWon !== null && (
                    <p
                      className={
                        shellWon
                          ? 'game-page__result game-page__result--success'
                          : 'game-page__result'
                      }
                      role='status'
                    >
                      {shellWon
                        ? '정답입니다. 공을 찾았습니다!'
                        : '아쉽지만 빈 컵입니다.'}
                    </p>
                  )}
                  <div className='game-page__shell-action-bar'>
                    <div className='game-page__bet-group'>
                      <label className='game-page__bet-control'>
                        <span>배팅</span>
                        <input
                          type='text'
                          inputMode='numeric'
                          pattern='[0-9]*'
                          value={bet}
                          onChange={(event) => {
                            setBet(
                              Number(
                                event.currentTarget.value.replace(/\D/g, ''),
                              ),
                            );
                          }}
                        />
                      </label>
                    </div>
                    <button
                      type='button'
                      className='game-page__primary-action'
                      disabled={busy || bet <= 0 || shellRemaining === 0}
                      onClick={() => void playShellGame()}
                    >
                      {shellShuffling ? '진행 중…' : '도전하기'}
                    </button>
                  </div>
                </section>
              )}

              {gambleView === 'simon' && (
                <section className='game-page__game-component game-page__simon'>
                  <div className='game-page__game-toolbar'>
                    <header className='game-page__game-header'>
                      <div>
                        <h3>Simon 기억력 게임</h3>
                        <p>키보드 숫자 1~4로도 입력할 수 있습니다.</p>
                      </div>
                      <div className='game-page__game-header-actions'>
                        <span className='game-page__game-badge'>
                          오늘 {simonRemaining} / 3회
                        </span>
                        <button
                          type='button'
                          className='game-page__back'
                          disabled={busy}
                          onClick={backToGambleList}
                        >
                          ←
                        </button>
                      </div>
                    </header>
                  </div>
                  <div
                    className={
                      simonCountdown !== null
                        ? 'game-page__simon-stage is-countdown'
                        : simon && !simonAccepting
                          ? 'game-page__simon-stage is-showing'
                          : 'game-page__simon-stage'
                    }
                  >
                    {simonCountdown !== null && (
                      <div
                        className='game-page__simon-countdown'
                        aria-atomic='true'
                        aria-live='assertive'
                        key={simonCountdown}
                        role='status'
                      >
                        <span>ROUND {simon?.round}</span>
                        <strong>{simonCountdown}</strong>
                        <small>준비하세요</small>
                      </div>
                    )}
                    <div
                      className={
                        simonAccepting
                          ? 'game-page__simon-status is-input'
                          : simon
                            ? 'game-page__simon-status is-showing'
                            : 'game-page__simon-status'
                      }
                      aria-live='polite'
                    >
                      <div>
                        <span>{simonMessage}</span>
                        <div
                          className='game-page__simon-progress'
                          aria-hidden='true'
                        >
                          <i
                            style={{
                              width: `${simon ? (simonInput.length / simon.sequence.length) * 100 : 0}%`,
                            }}
                          />
                        </div>
                      </div>
                      <strong>
                        {simon
                          ? `${simonInput.length} / ${simon.sequence.length}`
                          : '준비'}
                      </strong>
                    </div>
                    <div
                      className={
                        simonAccepting
                          ? 'game-page__simon-board is-input'
                          : 'game-page__simon-board game-page__simon-board--locked'
                      }
                    >
                      {[0, 1, 2, 3].map((panel) => (
                        <button
                          type='button'
                          aria-label={`Simon 패널 ${panel + 1}`}
                          className={
                            simonActivePanel === panel ? 'active' : undefined
                          }
                          disabled={!simonAccepting}
                          key={panel}
                          onClick={() => {
                            chooseSimonPanel(panel);
                          }}
                        >
                          {panel + 1}
                        </button>
                      ))}
                    </div>
                  </div>
                  <div className='game-page__simon-footer'>
                    <span>
                      {simon
                        ? `${simon.round}라운드 · 순서를 기억하세요.`
                        : `5라운드를 통과하면 보상을 받습니다. 오늘 ${simonRemaining}회 남음`}
                    </span>
                    <button
                      type='button'
                      className='game-page__primary-action'
                      disabled={
                        busy ||
                        simonAccepting ||
                        !!simon ||
                        simonRemaining === 0
                      }
                      onClick={() => void startSimon()}
                    >
                      {simon ? '순서를 확인하는 중…' : '게임 시작'}
                    </button>
                  </div>
                </section>
              )}

              {gambleView === 'blackjack' && (
                <section className='game-page__game-component game-page__blackjack'>
                  <div className='game-page__game-toolbar'>
                    <header className='game-page__game-header'>
                      <div>
                        <h3>블랙잭</h3>
                        <p>딜러보다 높은 합계를 만들되, 21을 넘기지 마세요.</p>
                      </div>
                      <div className='game-page__game-header-actions'>
                        <span className='game-page__game-badge'>
                          오늘 {blackjackRemaining} / 3회
                        </span>
                        <button
                          type='button'
                          className='game-page__back'
                          disabled={
                            busy || (!!blackjack && !blackjack.finished)
                          }
                          onClick={backToGambleList}
                        >
                          ← 목록
                        </button>
                      </div>
                    </header>
                  </div>

                  <div className='game-page__blackjack-table'>
                    <div className='game-page__blackjack-hand'>
                      <div className='game-page__blackjack-hand-label'>
                        <span>DEALER</span>
                        <strong>
                          {blackjack?.finished
                            ? blackjack.dealer_total
                            : blackjack
                              ? '?'
                              : '—'}
                        </strong>
                      </div>
                      <div className='game-page__playing-cards'>
                        {(blackjack?.dealer_cards ?? []).map((card, index) => (
                          <span
                            className={
                              isRedSuit(card.suit)
                                ? 'game-page__playing-card is-red'
                                : 'game-page__playing-card'
                            }
                            key={`${card.rank}-${card.suit}-${index}`}
                          >
                            <b>{card.rank}</b>
                            <i>{card.suit}</i>
                          </span>
                        ))}
                        {!blackjack && (
                          <span className='game-page__playing-card is-hidden'>
                            ?
                          </span>
                        )}
                      </div>
                    </div>

                    <div className='game-page__blackjack-divider'>VS</div>

                    <div className='game-page__blackjack-hand'>
                      <div className='game-page__blackjack-hand-label'>
                        <span>PLAYER</span>
                        <strong>{blackjack?.player_total ?? '—'}</strong>
                      </div>
                      <div className='game-page__playing-cards'>
                        {(blackjack?.player_cards ?? []).map((card, index) => (
                          <span
                            className={
                              isRedSuit(card.suit)
                                ? 'game-page__playing-card is-red'
                                : 'game-page__playing-card'
                            }
                            key={`${card.rank}-${card.suit}-${index}`}
                          >
                            <b>{card.rank}</b>
                            <i>{card.suit}</i>
                          </span>
                        ))}
                        {!blackjack && (
                          <span className='game-page__blackjack-empty'>
                            카드를 받으세요
                          </span>
                        )}
                      </div>
                    </div>
                  </div>

                  <div className='game-page__blackjack-controls'>
                    {!blackjack || blackjack.finished ? (
                      <>
                        <div className='game-page__bet-group'>
                          <label className='game-page__bet-control game-page__blackjack-bet'>
                            <span>배팅</span>
                            <input
                              type='text'
                              inputMode='numeric'
                              pattern='[0-9]*'
                              value={bet}
                              onChange={(event) => {
                                setBet(
                                  Number(
                                    event.currentTarget.value.replace(
                                      /\D/g,
                                      '',
                                    ),
                                  ),
                                );
                              }}
                            />
                          </label>
                        </div>
                        <button
                          type='button'
                          className='game-page__blackjack-start'
                          disabled={
                            busy || bet <= 0 || blackjackRemaining === 0
                          }
                          onClick={() => void startBlackjack()}
                        >
                          {blackjack?.finished ? '다시 배팅하기' : '게임 시작'}
                        </button>
                      </>
                    ) : (
                      <>
                        <span className='game-page__blackjack-status'>
                          배팅 {blackjack.bet} 재화 · 현재 합계{' '}
                          {blackjack.player_total}
                        </span>
                        <button
                          type='button'
                          className='game-page__blackjack-hit'
                          disabled={busy}
                          onClick={() => void playBlackjack('hit')}
                        >
                          히트
                        </button>
                        <button
                          type='button'
                          className='game-page__blackjack-stand'
                          disabled={busy}
                          onClick={() => void playBlackjack('stand')}
                        >
                          스탠드
                        </button>
                      </>
                    )}
                  </div>
                  {blackjack?.finished && (
                    <p
                      className={`game-page__blackjack-result is-${blackjack.outcome}`}
                      role='status'
                    >
                      {blackjack.message}{' '}
                      {blackjack.payout ? `지급 재화 ${blackjack.payout}` : ''}
                    </p>
                  )}
                </section>
              )}
            </div>
          )}
        </main>
      </div>
      <Helmet>
        <title>게임 상점</title>
        <meta name='robots' content='noindex' />
      </Helmet>
    </Column>
  );
};

// eslint-disable-next-line import/no-default-export
export default Game;
