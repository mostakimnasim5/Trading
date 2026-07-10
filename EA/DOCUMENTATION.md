# InstitutionalTraderEA - Complete Documentation

## 1. INPUT PARAMETERS WITH DEFAULT VALUES

### Symbol & Basic
| Parameter | Default | Description |
|-----------|---------|-------------|
| `InpSymbol` | EURUSD | Trading symbol |
| `InpTradeMode` | BOTH | Trading mode (Trend/Mean_Rev/Both) |
| `InpMagicNumber` | 2025001 | Magic number for trade identification |

### Risk Management
| Parameter | Default | Description |
|-----------|---------|-------------|
| `InpRiskPercent` | 1.0 | Risk per trade (%) |
| `InpFixedLot` | 0.0 | Fixed lot size (0 = use risk %) |
| `InpMaxSpread` | 25 | Maximum spread (points) |
| `InpMaxSlippage` | 30 | Maximum slippage (points) |
| `InpDailyLossLimit` | 5.0 | Daily loss limit (%) |
| `InpMaxConsecutiveLoss` | 5 | Max consecutive losses before pause |
| `InpMaxGlobalTrades` | 3 | Max trades per day |
| `InpCooldownMinutes` | 15 | Cooldown after each trade (minutes) |
| `InpMinTradeDistance` | 50 | Minimum distance from price (points) |

### Session Times (GMT)
| Parameter | Default | Description |
|-----------|---------|-------------|
| `InpAsianStartHour` | 0 | Asian session start |
| `InpAsianEndHour` | 9 | Asian session end |
| `InpLondonStartHour` | 7 | London session start |
| `InpLondonEndHour` | 11 | London session end |
| `InpNewYorkStartHour` | 12 | New York session start |
| `InpNewYorkEndHour` | 16 | New York session end |
| `InpDeadZoneStartHour` | 16 | Dead zone start |
| `InpDeadZoneEndHour` | 21 | Dead zone end |

### Trend Engine (SMC)
| Parameter | Default | Description |
|-----------|---------|-------------|
| `InpUseTrendEngine` | true | Enable trend/SMC engine |
| `InpTrendTimeframe` | 5 | Main timeframe (minutes) |
| `InpHTFConfirm` | 60 | Higher TF confirmation (H1) |
| `InpADXPeriod` | 14 | ADX period |
| `InpADXMinStrength` | 25 | Minimum ADX for trade |
| `InpRSIPeriod` | 14 | RSI period |
| `InpRSIOverbought` | 70 | RSI overbought level |
| `InpRSIOversold` | 30 | RSI oversold level |
| `InpMACDFast` | 12 | MACD fast EMA |
| `InpMACDSlow` | 26 | MACD slow EMA |
| `InpMACDSignal` | 9 | MACD signal line |

### ATR & Volatility
| Parameter | Default | Description |
|-----------|---------|-------------|
| `InpATRPeriod` | 14 | ATR period |
| `InpATRSLMultiplier` | 1.5 | SL distance (ATR multiples) |
| `InpATRTPMultiplier` | 2.5 | TP distance (ATR multiples) |
| `InpMinVolatility` | 10 | Min ATR for trade |
| `InpMaxVolatility` | 500 | Max ATR for trade |

### Volume Settings
| Parameter | Default | Description |
|-----------|---------|-------------|
| `InpVolumePeriod` | 20 | Volume MA period |
| `InpVolumeSpikeMultiplier` | 2.0 | Volume spike threshold |
| `InpUseVolumeFilter` | true | Enable volume filter |
| `InpUseVolumeProfile` | false | Enable volume profile filter |

### Bollinger Band (Mean Reversion)
| Parameter | Default | Description |
|-----------|---------|-------------|
| `InpUseMeanRevEngine` | true | Enable mean reversion engine |
| `InpBBPeriod` | 20 | Bollinger period |
| `InpBBDeviation` | 2.0 | Bollinger deviation |
| `InpBBTimeframe` | 5 | BB timeframe |

### VWAP Settings
| Parameter | Default | Description |
|-----------|---------|-------------|
| `InpUseVWAP` | true | Use VWAP |
| `InpVWAPSession` | 1 | VWAP session (0=Day, 1=Week) |
| `InpVWAPDeviation` | 1.0 | VWAP deviation bands |

### Confirmation Settings
| Parameter | Default | Description |
|-----------|---------|-------------|
| `InpMinConfirmations` | 3 | Minimum required confirmations |
| `InpConfidenceThreshold` | 60 | Minimum confidence score (%) |
| `InpUseDXYFilter` | false | Use DXY correlation filter |
| `InpDXYSymbol` | DXY | DXY symbol |
| `InpDXYThreshold` | 0.5 | DXY correlation threshold |
| `InpUseVIXFilter` | false | Use VIX filter |
| `InpVIXSymbol` | VIX | VIX symbol |
| `InpVIXMax` | 25 | VIX maximum level |
| `InpUseNewsFilter` | false | Use news filter (future) |
| `InpUseTrendFilter` | true | Use trend filter |

### Exit Management
| Parameter | Default | Description |
|-----------|---------|-------------|
| `InpBreakEvenTrigger` | 1.0 | Break-even trigger (ATR multiples) |
| `InpBreakEvenBuffer` | 0.5 | Break-even buffer (ATR) |
| `InpUsePartialClose` | true | Use partial close |
| `InpPartialClosePercent` | 50 | Partial close percentage |
| `InpTP1Percent` | 50 | TP1 distance (%) |
| `InpUseTrailingStop` | true | Use trailing stop |
| `InpTrailStartPercent` | 50 | Trail start after TP% |
| `InpTrailDistancePercent` | 30 | Trail distance % |

### Debug & Logging
| Parameter | Default | Description |
|-----------|---------|-------------|
| `InpDebugMode` | false | Enable debug mode |
| `InpVerboseLogging` | true | Verbose trade logging |

---

## 2. STRATEGY LOGIC EXPLANATION

### Dual-Mode Trading System

This EA operates in two distinct modes based on market sessions:

#### ENGINE 1: TREND / SMC LOGIC (London & New York Kill Zones)

**Purpose**: Capture institutional directional moves during high-liquidity sessions.

**Entry Conditions (BUY)**:
1. Price above 50 EMA (uptrend)
2. ADX >= 25 (strong trend)
3. RSI between 30-70 (not extreme)
4. MACD histogram positive or improving
5. Volume spike present (>= 2x average)
6. Higher timeframe confirms uptrend (H4)
7. Optional: DXY not extreme, VIX below threshold
8. Candlestick confirmation (bullish patterns)

**Entry Conditions (SELL)**:
- Mirror of BUY conditions for bearish direction

**Risk Management**:
- SL: ATR × 1.5 (structure-based)
- TP: ATR × 2.5 (R:R = 1:1.67)
- Break-even after 1 ATR profit
- Partial close at 50% TP
- Trailing stop after TP reached

#### ENGINE 2: MEAN REVERSION (Asian & Dead Zone Sessions)

**Purpose**: Trade range-bound reversions during low-volatility periods.

**Entry Conditions (BUY - Mean Reversion)**:
1. Price below Bollinger Lower Band
2. RSI < 30 (oversold)
3. RSI showing reversal signs
4. Low volume (exhaustion)
5. Bullish pin bar / rejection candle
6. Price above VWAP (if enabled)
7. Bollinger Band expanding

**Entry Conditions (SELL - Mean Reversion)**:
- Mirror of BUY for overbought conditions

**Risk Management**:
- Wider SL: ATR × 1.8 (sweep zones need buffer)
- TP: Middle band or VWAP
- Break-even protection
- No trailing until TP1 reached

### Session-Based Mode Switching

| Session | Time (GMT) | Engine Active |
|---------|------------|---------------|
| Asian | 00:00 - 09:00 | Mean Reversion |
| London Kill Zone | 07:00 - 11:00 | Trend/SMC |
| New York Kill Zone | 12:00 - 16:00 | Trend/SMC |
| Dead Zone | 16:00 - 21:00 | Mean Reversion |

---

## 3. RISK MANAGEMENT EXPLANATION

### Position Sizing
- **Risk Percentage**: 1% of account per trade (default)
- **Fixed Lot**: Optional alternative
- **Lot Calculation**: Based on SL distance and account balance
- **Broker Compliance**: Respects min/max lot and lot step

### Protective Limits
- **Daily Loss Limit**: 5% (configurable)
- **Consecutive Loss Limit**: 5 losses (pauses trading)
- **Global Trade Limit**: 3 trades per day
- **Cooldown**: 15 minutes between trades

### Trade Filters
- **Spread Filter**: Max 25 points
- **Slippage Filter**: Max 30 points
- **Margin Check**: Blocks if margin < 150%
- **Stale Data Check**: Blocks if tick > 1 minute old

### Exit Management Hierarchy
1. **Partial Close**: 50% at TP1 (50% of full TP distance)
2. **Break-Even**: SL moved to entry after 1 ATR profit
3. **Trailing Stop**: SL trails after TP1 reached
4. **Full Close**: At TP2 or SL hit

---

## 4. TESTING CHECKLIST

### Backtesting Requirements

- [ ] Load on MT5 Strategy Tester
- [ ] Select appropriate date range (min 6 months)
- [ ] Use "Every tick" or "1 minute OHLC" for accuracy
- [ ] Enable visual mode for signal verification
- [ ] Test on multiple symbols
- [ ] Test across different time periods
- [ ] Compare results with/without filters

### Optimization Parameters (Start with these)

1. **Start with conservative values**:
   - InpRiskPercent: 0.5-1.0
   - InpMinConfirmations: 3-4
   - InpConfidenceThreshold: 60-70

2. **Primary optimization targets**:
   - InpADXMinStrength (20-35)
   - InpATRSLMultiplier (1.0-2.5)
   - InpATRTPMultiplier (2.0-4.0)

3. **Secondary targets**:
   - InpMinConfirmations (2-5)
   - InpConfidenceThreshold (50-80)
   - Session time windows

### Forward Testing Requirements

- [ ] Demo account with real market conditions
- [ ] Minimum 1 month forward test
- [ ] Verify live signal quality matches backtest
- [ ] Monitor slippage and execution quality
- [ ] Track actual vs expected results

### Pre-Production Checklist

- [ ] Test on ECN/DMA broker (if possible)
- [ ] Verify spread conditions match backtest
- [ ] Confirm margin requirements
- [ ] Test emergency close function (F12)
- [ ] Verify news filter works correctly
- [ ] Check broker swap/commission impact

### Expected Performance Ranges

| Metric | Conservative | Moderate | Aggressive |
|--------|--------------|----------|------------|
| Win Rate | 45-55% | 55-65% | 65-75% |
| Risk:Reward | 1:1.5 | 1:2 | 1:2.5 |
| Max Drawdown | 5-8% | 8-15% | 15-25% |
| Daily Trades | 1-2 | 2-4 | 4-6 |
| Monthly Return | 3-5% | 5-10% | 10-20% |

---

## 5. IMPORTANT NOTES

### Realistic Expectations

- **No system guarantees 75% win rate consistently**
- Win rate depends heavily on market conditions
- **Focus on risk-adjusted returns, not just win rate**
- A 50% win rate with 1:2 R:R is profitable
- **Lower drawdown is more important than higher returns**

### Common Mistakes to Avoid

1. **Over-optimization**: Don't curve-fit to historical data
2. **Ignoring transaction costs**: Spreads, swaps, commissions matter
3. **Trading during news**: Always enable news filter
4. **Ignoring margin**: Leave buffer for adverse moves
5. **Revenge trading**: Cooldown exists for a reason

### Code Quality Features

- All arrays validated before use
- NaN/invalid value protection
- No repainting indicators
- Closed candle confirmation only
- Robust error handling for broker calls
- Comprehensive logging for debugging

---

## 6. COMPILATION & INSTALLATION

### Compilation
1. Open MetaEditor (F4 in MT5)
2. File → Open → Select `InstitutionalTraderEA.mq5`
3. Click Compile (F7)
4. Check for errors in Errors tab

### Installation
1. Copy `.mq5` file to MT5 Data Folder → MQL5 → Experts
2. Refresh Experts in Navigator
3. Drag EA to chart
4. Configure input parameters
5. Enable automated trading

### Required Indicator Files
- EA uses built-in MT5 indicators
- No external files required
- DXY/VIX filters optional (safely disabled by default)

---

*Document Version: 2.0*
*Last Updated: 2026*
