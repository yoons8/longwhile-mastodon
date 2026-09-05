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
  inventory: GameItem[];
  shops: GameShop[];
}

interface SimonState {
  token: string;
  round: number;
  sequence: number[];
  success?: boolean;
  complete?: boolean;
  reward?: number;
}

type Tab = 'shop' | 'gamble';
type GambleView = 'list' | 'shell' | 'simon';

const errorMessage = (error: unknown) => {
  if (typeof error === 'object' && error !== null && 'response' in error) {
    const response = (error as { response?: { data?: { error?: string } } }).response;
    if (response?.data?.error) return response.data.error;
  }

  return '요청을 처리하지 못했습니다.';
};

const delay = (milliseconds: number) =>
  new Promise<void>((resolve) => window.setTimeout(resolve, milliseconds));

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
  const [simonAccepting, setSimonAccepting] = useState(false);
  const [simonMessage, setSimonMessage] = useState('시작 버튼을 누르세요.');

  const loadState = useCallback(async () => {
    const response = await api().get<GameState>('/game/state');
    setState(response.data);
    setSelectedItem((current) => current ?? response.data.shops[0]?.items[0] ?? response.data.inventory[0] ?? null);
  }, []);

  useEffect(() => {
    void loadState().catch((error: unknown) => { setMessage(errorMessage(error)); });
  }, [loadState]);

  const selectItem = useCallback((item: GameItem) => {
    setSelectedItem(item);
    const price = item.price === undefined ? '' : ` · ${item.price} 재화`;
    setMessage(`${item.name} — ${item.description || '설명이 없습니다.'}${price}`);
  }, []);

  const openGamble = useCallback(() => {
    setTab('gamble');
    setGambleView('list');
    setSimonAccepting(false);
    setMessage('오늘은 어떤 게임에 도전하시겠습니까?');
  }, []);

  const openGambleGame = useCallback((view: Exclude<GambleView, 'list'>, description: string) => {
    setGambleView(view);
    setShellAnswer(null);
    setShellWon(null);
    setMessage(description);
  }, []);

  const backToGambleList = useCallback(() => {
    setGambleView('list');
    setSimonAccepting(false);
    setMessage('게임을 선택하세요.');
  }, []);

  const act = useCallback(async (path: string, data: Record<string, unknown>, success: (result: Record<string, unknown>) => string) => {
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
  }, [busy, loadState]);

  const playShellGame = useCallback(async () => {
    if (busy || bet <= 0) return;
    setBusy(true);
    setShellShuffling(true);
    setShellAnswer(null);
    setShellWon(null);
    setMessage('컵을 섞고 있습니다…');
    try {
      const response = await api().post<{ won: boolean; answer: number; currency_change: number }>('/game/shell_game', { bet, cup });
      await delay(850);
      setShellAnswer(response.data.answer);
      setShellWon(response.data.won);
      setMessage(`${response.data.won ? '정답입니다!' : '아쉽군요.'} 공은 ${response.data.answer}번 컵 아래에 있습니다. 재화 ${response.data.currency_change >= 0 ? '+' : ''}${response.data.currency_change}`);
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
    setSimonMessage(`${nextSimon.round}라운드 · 순서를 기억하세요.`);
    await delay(450);
    for (const panel of nextSimon.sequence) {
      setSimonActivePanel(panel);
      await delay(350);
      setSimonActivePanel(null);
      await delay(140);
    }
    setSimonAccepting(true);
    setSimonMessage(`${nextSimon.sequence.length}개를 순서대로 입력하세요.`);
  }, []);

  const startSimon = useCallback(async () => {
    setBusy(true);
    try {
      const response = await api().post<SimonState>('/game/start_simon');
      setSimon(response.data);
      await showSequence(response.data);
    } catch (error) {
      setSimonMessage(errorMessage(error));
    } finally {
      setBusy(false);
    }
  }, [showSequence]);

  const submitSimon = useCallback(async (current: SimonState, input: number[]) => {
    setSimonAccepting(false);
    try {
      const response = await api().post<SimonState>('/game/submit_simon', { token: current.token, sequence: input });
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
  }, [loadState, showSequence]);

  const chooseSimonPanel = useCallback((panel: number) => {
    if (!simon || !simonAccepting) return;
    setSimonActivePanel(panel);
    window.setTimeout(() => { setSimonActivePanel(null); }, 180);
    const input = [...simonInput, panel];
    setSimonInput(input);
    if (input.length === simon.sequence.length) void submitSimon(simon, input);
  }, [simon, simonAccepting, simonInput, submitSimon]);

  useEffect(() => {
    const handleKeyDown = (event: KeyboardEvent) => {
      if (event.key >= '1' && event.key <= '4') chooseSimonPanel(Number(event.key) - 1);
    };
    document.addEventListener('keydown', handleKeyDown);
    return () => { document.removeEventListener('keydown', handleKeyDown); };
  }, [chooseSimonPanel]);

  return (
    <Column bindToDocument={!multiColumn} label='게임 상점'>
      <ColumnHeader title='' multiColumn={multiColumn} />
      <div className='scrollable game-page'>
        <section className='game-page__shopkeeper' aria-live='polite'>
          <div className='game-page__portrait' aria-hidden='true'>상점주인</div>
          <div className='game-page__shopkeeper-main'>
            <div className='game-page__speech'>
              <p>{message}</p>
              <span>재화 {state?.profile.currency ?? '—'} · 명성 {state?.profile.reputation ?? '—'}</span>
            </div>
            <nav className='game-page__tabs' aria-label='게임 메뉴'>
              <button type='button' disabled={busy} onClick={() => void act('/game/talk', {}, (result) => String(result.dialogue))}>대화</button>
              <button type='button' disabled={busy} onClick={() => void act('/game/vend', {}, (result) => `자판기에서 ${String(result.item)}을(를) 얻었습니다.`)}>자판기</button>
              <button type='button' className={tab === 'shop' ? 'active' : undefined} onClick={() => { setTab('shop'); }}>상점</button>
              <button type='button' className={tab === 'gamble' ? 'active' : undefined} onClick={openGamble}>갬블</button>
            </nav>
          </div>
        </section>

        <main className='game-page__content'>
          {tab === 'shop' ? (
            <>
              {state?.shops.length === 0 && (
                <p className='game-page__empty'>현재 이용 가능한 상점이 없습니다.</p>
              )}
              {state?.shops.map((shop) => (
                <section className={`game-page__shop game-page__shop--${shop.shop_type}`} key={shop.id}>
                  <header><strong>{shop.name}</strong><span>{shop.description}</span></header>
                  <div className='game-page__item-grid'>
                    {shop.items.length === 0 && (
                      <p className='game-page__empty'>등록된 상점 상품이 없습니다.</p>
                    )}
                    {shop.items.map((item) => (
                        <article className={selectedItem?.id === item.id ? 'game-page__item-card active' : 'game-page__item-card'} key={item.id}>
                          <button type='button' className='game-page__item-select' onClick={() => { selectItem(item); }}>
                            {item.image ? <img src={item.image} alt='' /> : <span className='game-page__mini-placeholder'>아이템</span>}
                            <strong>{item.name}</strong>
                            <span>{item.price} 재화</span>
                          </button>
                          <div className='game-page__card-actions'>
                            <button type='button' disabled={busy} onClick={() => void act('/game/purchase', { game_item_id: item.id }, () => `${item.name}을(를) 구매했습니다.`)}>구매</button>
                          </div>
                        </article>
                    ))}
                  </div>
                </section>
              ))}
              <section className='game-page__shop'>
                <header><strong>소지품</strong><span>보유 아이템을 선택해 판매할 수 있습니다.</span></header>
                <div className='game-page__item-grid'>
                  {state?.inventory.length === 0 && (
                    <p className='game-page__empty'>보유한 아이템이 없습니다.</p>
                  )}
                  {state?.inventory.map((item) => (
                    <article className={selectedItem?.id === item.id ? 'game-page__item-card active' : 'game-page__item-card'} key={item.id}>
                      <button type='button' className='game-page__item-select' onClick={() => { selectItem(item); }}>
                        {item.image ? <img src={item.image} alt='' /> : <span className='game-page__mini-placeholder'>아이템</span>}
                        <strong>{item.name}</strong>
                        <span>{item.quantity}개 · 판매가 {item.sale_price}</span>
                      </button>
                      <div className='game-page__card-actions'>
                        <button type='button' disabled={busy || !item.quantity} onClick={() => void act('/game/sell', { game_item_id: item.id, quantity: 1 }, () => `${item.name} 1개를 판매했습니다.`)}>판매</button>
                      </div>
                    </article>
                  ))}
                </div>
              </section>
            </>
          ) : (
            <div className='game-page__games'>
              {gambleView === 'list' && (
                <div className='game-page__gamble-list'>
                  <button type='button' onClick={() => { openGambleGame('shell', '컵 아래 숨겨진 공의 위치를 맞혀 보세요. 하루에 세 번 도전할 수 있습니다.'); }}>
                    <span className='game-page__game-icon' aria-hidden='true'>●</span>
                    <strong>야바위</strong>
                  </button>
                  <button type='button' onClick={() => { openGambleGame('simon', '빛나는 패널의 순서를 기억하고 그대로 입력하세요.'); }}>
                    <span className='game-page__game-icon' aria-hidden='true'>▦</span>
                    <strong>Simon 게임</strong>
                  </button>
                </div>
              )}

              {gambleView === 'shell' && (
                <section className='game-page__game-component'>
                  <button type='button' className='game-page__back' disabled={busy} onClick={backToGambleList}>← 뒤로</button>
                  <h3>야바위</h3>
                  <label>배팅액<input type='number' min={1} value={bet} onChange={(event) => { setBet(Number(event.currentTarget.value)); }} /></label>
                  <div className={shellShuffling ? 'game-page__cups game-page__cups--shuffling' : 'game-page__cups'}>
                    {[1, 2, 3].map((number) => (
                      <button type='button' className={cup === number ? 'active' : undefined} disabled={busy} aria-pressed={cup === number} key={number} onClick={() => { setCup(number); setShellAnswer(null); setShellWon(null); }}>
                        <span className='game-page__cup' aria-hidden='true'>⌒</span>
                        <span>{number}번 컵</span>
                        {shellAnswer === number && <span className='game-page__ball' aria-label='공'>●</span>}
                      </button>
                    ))}
                  </div>
                  {shellWon !== null && <p className={shellWon ? 'game-page__result game-page__result--success' : 'game-page__result'} role='status'>{shellWon ? '선택한 컵에서 공을 찾았습니다!' : '선택한 컵은 비어 있었습니다.'}</p>}
                  <button type='button' disabled={busy || bet <= 0} onClick={() => void playShellGame()}>{shellShuffling ? '섞는 중…' : '도전'}</button>
                </section>
              )}

              {gambleView === 'simon' && (
                <section className='game-page__game-component game-page__simon'>
                  <button type='button' className='game-page__back' disabled={busy} onClick={backToGambleList}>← 뒤로</button>
                  <h3>Simon 기억력 게임</h3>
                  <p aria-live='polite'>{simonMessage}</p>
                  <div className='game-page__simon-board'>
                    {[0, 1, 2, 3].map((panel) => <button type='button' aria-label={`Simon 패널 ${panel + 1}`} className={simonActivePanel === panel ? 'active' : undefined} disabled={!simonAccepting} key={panel} onClick={() => { chooseSimonPanel(panel); }}>{panel + 1}</button>)}
                  </div>
                  <button type='button' disabled={busy || simonAccepting} onClick={() => void startSimon()}>게임 시작</button>
                </section>
              )}
            </div>
          )}
        </main>
      </div>
      <Helmet><title>게임 상점</title><meta name='robots' content='noindex' /></Helmet>
    </Column>
  );
};

// eslint-disable-next-line import/no-default-export
export default Game;
