//+------------------------------------------------------------------+
//|      INSTITUTIONAL ALPHA ENGINE v5.0 - MQL5 CONVERSION            |
//|      DUAL-ENGINE DYNAMIC CORE  ·  24-HOUR FULL COVERAGE           |
//|                                                                |
//|      ENGINE 1 - Kill Zone SMC (6 hrs/day)                       |
//|          London Open 08:00-11:00 UK + NY Open 13:00-16:00 UTC  |
//|          Logic: MSS + Order Block + FVG + Volume + DXY + Delta  |
//|          Gate: 4 of 5 SMC criteria + all Alpha Filters         |
//|          RR: 1:2 minimum, 1:3 target with ATR trailing         |
//|                                                                |
//|      ENGINE 2 - Off-Kill-Zone Mean Reversion (13 hrs/day)      |
//|          Asian session + London-NY Bridge + Late NY             |
//|          Logic: Asia Range + BB(20,3σ) Sweep + Vol Exhaust     |
//|          Gate: ALL 5 conditions must fire                       |
//|          RR: 1:1 to 1:1.5, TP = VWAP/20-SMA                   |
//|                                                                |
//|      RISK: MaxTrades=1 · FixedLot=0.01 · BE=+10pip · MaxSpread|
//+------------------------------------------------------------------+

#property copyright "Institutional Alpha Engine v5.0"
#property version   "5.0"
#property strict

#include <Trade/Trade.mqh>

//+------------------------------------------------------------------+
//| ENUMERATIONS                                                     |
//+------------------------------------------------------------------+
enum ENUM_ENGINE_STATE
{
   ENGINE_KILLZONE_SMC     = 1,  // Engine 1: London/NY Kill Zones
   ENGINE_OFFZONE_REVERSION = 2, // Engine 2: Asian/Late-NY Mean Reversion
   ENGINE_DEAD_ZONE        = 3   // No trading (20:00-00:00 UTC)
};

enum ENUM_MARKET_BIAS
{
   BIAS_BULL    =  1,
   BIAS_BEAR    = -1,
   BIAS_RANGING =  0,
   BIAS_UNKNOWN = 99
};

enum ENUM_TRADE_DIRECTION
{
   DIRECTION_NONE  = 0,
   DIRECTION_BUY   = 1,
   DIRECTION_SELL  = -1
};

enum ENUM_FILTER_FAILURE
{
   FILTER_PASS         = 0,
   FILTER_KILL_ZONE    = 1,
   FILTER_DXY_CORR     = 2,
   FILTER_DELTA        = 3,
   FILTER_VOL_PROFILE  = 4,
   FILTER_VIX          = 5,
   FILTER_SPREAD       = 6,
   FILTER_NEWS         = 7,
   FILTER_SMC          = 8,
   FILTER_SUSPENDED    = 9,
   FILTER_NO_RANGE     = 10,
   FILTER_NO_SWEEP     = 11,
   FILTER_NO_REJECTION = 12,
   FILTER_RSI          = 13,
   FILTER_VOLUME       = 14,
   FILTER_LOW_RR       = 15
};

//+------------------------------------------------------------------+
//| INPUT PARAMETERS                                                 |
//+------------------------------------------------------------------+
input group "=== Connection ==="
input string   InpSymbol          = "EURUSD";       // Trading Symbol
input ulong    InpMagic           = 20260005;       // EA Magic Number
input int       InpGMT_Offset      = 0;              // Broker GMT Offset (0=UTC)

input group "=== Session Timing (DST-AWARE) ==="
input int       InpLondonKZ_Start  = 8;              // London KZ Start (UK time)
input int       InpLondonKZ_End    = 11;             // London KZ End (UK time)
input int       InpNYKZ_Start      = 8;              // NY KZ Start (EST)
input int       InpNYKZ_End        = 11;             // NY KZ End (EST)
input int       InpAsiaOpen        = 0;              // Asian Session Open (UTC)
input int       InpAsiaRangeHours  = 4;              // Hours to build Asia box
input int       InpDeadZoneStart   = 20;             // Dead Zone Start (UTC)

input group "=== Session Momentum ==="
input int       InpSessionMomBars  = 6;              // First 30 min (6x M5) for bias

input group "=== Timeframes ==="
input ENUM_TIMEFRAMES InpHTF_TF     = PERIOD_H1;     // Higher TF for OB/bias
input ENUM_TIMEFRAMES InpHTF_TF2    = PERIOD_H4;     // Second HTF for confirmation
input ENUM_TIMEFRAMES InpEntry_TF   = PERIOD_M5;     // Entry timeframe
input ENUM_TIMEFRAMES InpFVG_TF     = PERIOD_M15;     // FVG timeframe
input ENUM_TIMEFRAMES InpADX_TF     = PERIOD_M15;     // ADX/ATR timeframe

input group "=== Order Block Settings ==="
input int       InpOB_Lookback     = 50;             // Order Block lookback bars
input int       InpOB_MinAge       = 3;              // Min bar age for valid OB
input int       InpOB_MaxAge       = 20;             // Max bar age (older=ignore)
input double    InpOB_BufferPips   = 10.0;           // Proximity buffer (pips)
input double    InpOB_MinStrength  = 50.0;           // OB minimum strength

input group "=== FVG Settings ==="
input double    InpFVG_MinPips     = 2.0;            // FVG min pips
input int       InpFVG_MaxAgeBars  = 10;             // Max age for valid FVG
input bool      InpFVG_Mitigation  = true;           // Check if FVG not fully filled

input group "=== Entry Conditions ==="
input int       InpMinConfirmations = 4;             // Min of 5 pillars (4 of 5)
input double    InpVolSpikeMult    = 1.5;            // Volume spike multiplier
input int       InpVolMA_Period    = 20;             // Volume MA period
input int       InpRSI_Period      = 14;             // RSI period
input int       InpMACD_Fast       = 12;             // MACD fast
input int       InpMACD_Slow       = 26;             // MACD slow
input int       InpMACD_Signal     = 9;              // MACD signal
input int       InpADX_Period      = 14;             // ADX period
input double    InpADX_Min         = 25.0;           // ADX min threshold
input double    InpADX_Strong      = 35.0;           // ADX for strong trend
input int       InpDiv_Lookback    = 8;              // Divergence lookback
input int       InpATR_Period      = 14;             // ATR period
input double    InpATR_SL_Mult     = 1.5;            // ATR SL multiplier
input double    InpE1_TP1_RR       = 2.0;            // Engine 1 TP1 R:R
input double    InpE1_TP2_RR       = 3.0;            // Engine 1 TP2 R:R

input group "=== Displacement Detection ==="
input bool      InpUseDisplacement  = true;          // Enable displacement detection
input int       InpDisp_Lookback    = 20;            // Lookback bars for displacement
input int       InpDisp_MinBars     = 2;             // Minimum bars to engulf
input double    InpDisp_MinVolMult  = 1.5;           // Volume must be 1.5x average

input group "=== Breaker Block Detection ==="
input bool      InpUseBreakerBlock   = true;          // Enable breaker block detection
input int       InpBB_Lookback       = 30;           // Lookback for breaker blocks

input group "=== Volume Absorption ==="
input bool      InpUseAbsorption     = true;          // Enable volume absorption check
input int       InpAbsorption_Lookback = 20;          // Bars to check for absorption
input double    InpAbsorption_VolMult = 2.0;          // Volume must be 2x average

input group "=== Liquidity Sweep Quality ==="
input bool      InpLiqSweepQuality   = true;          // Enable sweep quality check
input int       InpLiqReversalBars   = 5;             // Must reverse within X bars
input double    InpLiqVolConfirm     = 1.3;           // Volume at sweep spike

input group "=== Spread Tolerance ==="
input double    InpMaxSpreadE1       = 25;            // Max spread points E1
input double    InpKZ_SpreadTol      = 2.0;           // Extra spread tolerance in KZ
input double    InpMaxSpreadE2       = 1.5;           // Max spread for E2

input group "=== DXY Correlation ==="
input bool      InpUseDXY            = true;          // Enable DXY correlation guard
input string    InpDXY_Symbol        = "DXY";         // DXY symbol on broker
input int       InpDXY_Lookback      = 20;            // DXY trend lookback bars

input group "=== Volume Profile ==="
input bool      InpUseVP             = true;          // Enable Volume Profile
input int       InpVP_Bars           = 100;           // VP calculation bars
input int       InpVP_Buckets        = 50;            // VP price buckets
input double    InpVP_ValueAreaPct   = 70.0;          // Value Area percentage
input double    InpVP_POC_BufferPips = 5.0;           // POC avoidance buffer

input group "=== VIX Cap ==="
input bool      InpUseVIX            = true;          // Enable VIX cap
input string    InpVIX_Symbol         = "VIX";         // Real VIX symbol
input double    InpVIX_MaxLevel      = 25.0;          // VIX halt threshold
input double    InpVIX_CautionLevel   = 20.0;         // VIX caution level

input group "=== Engine 2: Mean Reversion ==="
input ENUM_TIMEFRAMES InpE2_TF        = PERIOD_M5;    // Engine 2 sweep TF
input ENUM_TIMEFRAMES InpE2_ConfirmTF = PERIOD_M1;    // Engine 2 confirmation TF
input int       InpE2_BB_Period       = 20;           // Bollinger Band period
input double    InpE2_BB_StdDev       = 2.5;          // BB standard deviation
input double    InpE2_RSI_OB          = 65.0;         // RSI overbought
input double    InpE2_RSI_OS          = 35.0;         // RSI oversold
input double    InpE2_MinAsiaRange    = 25.0;         // Minimum Asia range (pips)
input double    InpE2_SweepMinPips    = 2.0;          // Min sweep pips
input int       InpE2_RejectionBars   = 5;            // Rejection lookback
input int       InpE2_PinbarWickPct   = 50;           // Pin bar wick %
input double    InpE2_VolExhaust      = 0.85;         // Vol exhaustion threshold
input int       InpE2_VWAP_Bars       = 100;          // VWAP calculation bars
input bool      InpE2_VWAP_Anchored   = true;         // Anchor VWAP to session start

input group "=== Position Management ==="
input double    InpBE_TriggerE2      = 10.0;          // E2 BE trigger (pips)
input double    InpTrailATR_Mult     = 0.75;          // ATR trailing multiplier
input double    InpBE_BufferPips      = 0.5;          // BE buffer (E2)
input int       InpBE_TriggerPtsE1    = 100;          // BE trigger points (E1)
input double    InpBE_BufferPipsE1    = 5.0;          // BE buffer pips (E1)
input double    InpPartialClosePct    = 50.0;         // Partial close % at TP1
input double    InpTrailStepPoints    = 10.0;         // Trailing step points

input group "=== Neural Feedback ==="
input double    InpE2_TP_MinPips     = 8.0;          // Min TP pips
input double    InpE2_TP_MaxPips     = 15.0;          // Max TP pips
input double    InpE2_TP_RR          = 1.5;          // Engine 2 R:R target
input int       InpNF_TradeMemory     = 50;           // Minimum trades for CB
input double    InpNF_MinAccuracy     = 65.0;         // Circuit breaker threshold
input int       InpNF_PauseMins       = 120;          // Circuit breaker pause

input group "=== Risk Management ==="
input double    InpRiskPct           = 1.0;           // Risk % of balance (E1)
input double    InpFixedLot           = 0.01;          // Fixed lot for E2
input double    InpMaxSpreadPips      = 2.5;           // Max spread pips E2
input int       InpMaxSpreadPtsE1     = 25;            // Max spread points E1
input int       InpMaxGlobalTrades    = 1;             // Max 1 trade globally
input int       InpMaxSlippage       = 3;             // Max slippage points
input int       InpStaleBlockSec      = 60;            // Stale data block seconds

input group "=== Execution ==="
input int       InpPollIntervalSec    = 2;             // Main loop poll interval
input int       InpDisplayIntervalSec  = 3;             // Dashboard refresh interval
input int       InpPositionMgmtSec     = 1;             // Position management interval

//+------------------------------------------------------------------+
//| GLOBAL VARIABLES                                                 |
//+------------------------------------------------------------------+
CTrade          g_trade;
datetime        g_last_bar_time      = 0;
datetime        g_last_pos_check     = 0;
datetime        g_last_closed_trades_check = 0;
datetime        g_last_asia_build    = 0;

// Engine states
ENUM_ENGINE_STATE     g_current_engine   = ENGINE_DEAD_ZONE;
ENUM_MARKET_BIAS      g_market_bias      = BIAS_UNKNOWN;
ENUM_TRADE_DIRECTION  g_current_direction = DIRECTION_NONE;

// Neural Feedback Stats
struct EngineStats
{
   int      total_trades;
   int      wins;
   double   accuracy;
   bool     is_paused;
   datetime paused_until;
   int      today_trades;
   double   today_pnl;
   int      win_streak;
   int      loss_streak;
};
EngineStats g_e1_stats, g_e2_stats;

// Data caches
datetime      g_cache_atr_time       = 0;
datetime      g_cache_adx_time       = 0;
double        g_pip_size            = 0;
double        g_point               = 0;

// Volume Profile
struct VPResult { double poc, vah, val; bool is_valid; };
VPResult g_vp;

// Asia Range Box
struct AsiaBox { double hi, lo, mid, size_pips; datetime built_date; bool is_valid, hi_swept, lo_swept; };
AsiaBox g_asia_box;

// Partial close tracking
struct PartialInfo { int ticket; bool done; datetime time; };
PartialInfo g_partial_info[];

//+------------------------------------------------------------------+
//| Helper Functions                                                 |
//+------------------------------------------------------------------+
double GetPipSize()
{
   if(g_pip_size > 0) return g_pip_size;
   int digits = (int)SymbolInfoInteger(InpSymbol, SYMBOL_DIGITS);
   if(digits == 3 || digits == 5)
      g_pip_size = MathPow(10, -digits + 1);
   else
      g_pip_size = MathPow(10, -digits);
   return g_pip_size;
}

double GetPoint()
{
   if(g_point > 0) return g_point;
   g_point = SymbolInfoDouble(InpSymbol, SYMBOL_POINT);
   return g_point;
}

double PointsToPips(double points)
{
   return points * GetPipSize() / GetPoint();
}

double PipsToPoints(double pips)
{
   return pips * GetPoint() / GetPipSize();
}

datetime GetBarTime(ENUM_TIMEFRAMES tf, int shift)
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(InpSymbol, tf, shift, 1, rates) <= 0) return 0;
   return rates[0].time;
}

double GetClose(int shift, ENUM_TIMEFRAMES tf = PERIOD_CURRENT)
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(InpSymbol, tf, 0, shift + 1, rates) <= 0) return 0;
   return rates[shift].close;
}

double GetOpen(int shift, ENUM_TIMEFRAMES tf = PERIOD_CURRENT)
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(InpSymbol, tf, 0, shift + 1, rates) <= 0) return 0;
   return rates[shift].open;
}

double GetHigh(int shift, ENUM_TIMEFRAMES tf = PERIOD_CURRENT)
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(InpSymbol, tf, 0, shift + 1, rates) <= 0) return 0;
   return rates[shift].high;
}

double GetLow(int shift, ENUM_TIMEFRAMES tf = PERIOD_CURRENT)
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(InpSymbol, tf, 0, shift + 1, rates) <= 0) return 0;
   return rates[shift].low;
}

long GetTickVolume(int shift, ENUM_TIMEFRAMES tf = PERIOD_CURRENT)
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(InpSymbol, tf, 0, shift + 1, rates) <= 0) return 0;
   return rates[shift].tick_volume;
}

double GetSpreadPips()
{
   double ask = SymbolInfoDouble(InpSymbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(InpSymbol, SYMBOL_BID);
   if(ask <= 0 || bid <= 0) return 0;
   double spread_points = ask - bid;
   double pip_size = GetPipSize();
   if(pip_size <= 0) return 0;
   return spread_points / pip_size;
}

int GetUTC_Hour()
{
   datetime server_time = TimeCurrent();
   MqlDateTime st;
   TimeToStruct(server_time, st);
   return st.hour - InpGMT_Offset;
}

datetime GetTodayMidnightUTC()
{
   datetime now = TimeCurrent() - InpGMT_Offset * 3600;
   MqlDateTime st;
   TimeToStruct(now, st);
   st.hour = 0; st.min = 0; st.sec = 0;
   return StructToTime(st) + InpGMT_Offset * 3600;
}

int GetHour()
{
   MqlDateTime st;
   TimeToStruct(TimeCurrent(), st);
   return st.hour;
}

//+------------------------------------------------------------------+
//| INDICATOR FUNCTIONS                                               |
//+------------------------------------------------------------------+

// RSI Indicator
double CalculateRSI(int period, int shift, ENUM_TIMEFRAMES tf = PERIOD_CURRENT)
{
   double rsi = iRSI(InpSymbol, tf, period, PRICE_CLOSE, shift);
   if(rsi == EMPTY_VALUE || rsi == 0) return 50.0;
   return rsi;
}

// ATR Indicator
double CalculateATR(int period, int shift, ENUM_TIMEFRAMES tf = PERIOD_CURRENT)
{
   double atr = iATR(InpSymbol, tf, period, shift);
   if(atr == EMPTY_VALUE || atr <= 0)
   {
      double hl_avg = 0;
      int count = 0;
      for(int i = shift; i < shift + period && i < 50; i++)
      {
         hl_avg += GetHigh(i, tf) - GetLow(i, tf);
         count++;
      }
      if(count > 0) return hl_avg / count;
      return 0;
   }
   return atr;
}

// Cached ATR
double GetCachedATR()
{
   datetime now = TimeCurrent();
   if(g_cache_atr_time != now && (now - g_cache_atr_time) > 15)
   {
      g_cache_atr_time = now;
      return CalculateATR(InpATR_Period, 0, InpADX_TF);
   }
   return CalculateATR(InpATR_Period, 0, InpADX_TF);
}

// ADX Indicator
double CalculateADX(int period, int shift, ENUM_TIMEFRAMES tf = PERIOD_CURRENT)
{
   double adx = iADX(InpSymbol, tf, period, PRICE_CLOSE, MODE_MAIN, shift);
   if(adx == EMPTY_VALUE || adx < 0) return 0;
   return adx;
}

// Cached ADX
double GetCachedADX()
{
   datetime now = TimeCurrent();
   if(g_cache_adx_time != now && (now - g_cache_adx_time) > 15)
   {
      g_cache_adx_time = now;
      return CalculateADX(InpADX_Period, 0, InpADX_TF);
   }
   return CalculateADX(InpADX_Period, 0, InpADX_TF);
}

// Bollinger Bands
void CalculateBB(double &upper[], double &middle[], double &lower[],
                 int period, double std_dev, int shift,
                 ENUM_TIMEFRAMES tf = PERIOD_CURRENT)
{
   ArraySetAsSeries(upper, true);
   ArraySetAsSeries(middle, true);
   ArraySetAsSeries(lower, true);
   
   double up_buf[], mid_buf[], lo_buf[];
   ArraySetAsSeries(up_buf, true);
   ArraySetAsSeries(mid_buf, true);
   ArraySetAsSeries(lo_buf, true);
   
   int handle = iBands(InpSymbol, tf, period, 0, std_dev, PRICE_CLOSE);
   if(handle == INVALID_HANDLE) return;
   
   ArrayResize(up_buf, shift + 1);
   ArrayResize(mid_buf, shift + 1);
   ArrayResize(lo_buf, shift + 1);
   
   CopyBuffer(handle, 0, shift, shift + 1, mid_buf);
   CopyBuffer(handle, 1, shift, shift + 1, up_buf);
   CopyBuffer(handle, 2, shift, shift + 1, lo_buf);
   
   ArrayResize(upper, shift + 1);
   ArrayResize(middle, shift + 1);
   ArrayResize(lower, shift + 1);
   
   for(int i = 0; i <= shift; i++)
   {
      upper[i] = up_buf[i];
      middle[i] = mid_buf[i];
      lower[i] = lo_buf[i];
   }
   
   IndicatorRelease(handle);
}

// EMA
double CalculateEMA(int period, int shift, ENUM_TIMEFRAMES tf = PERIOD_CURRENT)
{
   return iMA(InpSymbol, tf, period, 0, MODE_EMA, PRICE_CLOSE, shift);
}

// SMA
double CalculateSMA(int period, int shift, ENUM_TIMEFRAMES tf = PERIOD_CURRENT)
{
   return iMA(InpSymbol, tf, period, 0, MODE_SMA, PRICE_CLOSE, shift);
}

// Linear Regression Slope
double LinearRegressionSlope(double &values[])
{
   int n = ArraySize(values);
   if(n < 3) return 0;
   
   double sum_x = 0, sum_y = 0, sum_xy = 0, sum_x2 = 0;
   for(int i = 0; i < n; i++)
   {
      sum_x += i;
      sum_y += values[i];
      sum_xy += i * values[i];
      sum_x2 += i * i;
   }
   
   double denom = n * sum_x2 - sum_x * sum_x;
   if(MathAbs(denom) < 1e-12) return 0;
   
   double slope = (n * sum_xy - sum_x * sum_y) / denom;
   if(!MathIsValidNumber(slope)) return 0;
   return slope;
}

//+------------------------------------------------------------------+
//| MARKET BIAS DETECTION                                             |
//+------------------------------------------------------------------+
ENUM_MARKET_BIAS DetectBias(ENUM_TIMEFRAMES tf, int lookback = 30)
{
   double highs[], lows[];
   ArraySetAsSeries(highs, true);
   ArraySetAsSeries(lows, true);
   
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   int count = CopyRates(InpSymbol, tf, 0, lookback + 5, rates);
   if(count <= 0) return BIAS_UNKNOWN;
   
   ArrayResize(highs, count);
   ArrayResize(lows, count);
   
   for(int i = 0; i < count; i++)
   {
      highs[i] = rates[i].high;
      lows[i] = rates[i].low;
   }
   
   int hh = 0, hl = 0, ll = 0, lh = 0;
   double prev_h = -1e10, prev_l = 1e10;
   bool last_was_high = false;
   
   for(int i = 2; i < lookback - 2 && i < count - 2; i++)
   {
      bool is_swH = highs[i] > highs[i-1] && highs[i] > highs[i+1] && 
                    highs[i] > highs[i-2] && highs[i] > highs[i+2];
      bool is_swL = lows[i] < lows[i-1] && lows[i] < lows[i+1] && 
                    lows[i] < lows[i-2] && lows[i] < lows[i+2];
      
      if(is_swH && !last_was_high)
      {
         if(highs[i] > prev_h) hh++;
         else lh++;
         prev_h = highs[i];
         last_was_high = true;
      }
      if(is_swL && last_was_high)
      {
         if(lows[i] > prev_l) hl++;
         else ll++;
         prev_l = lows[i];
         last_was_high = false;
      }
   }
   
   if(hh >= 2 && hl >= 1) return BIAS_BULL;
   if(ll >= 2 && lh >= 1) return BIAS_BEAR;
   return BIAS_RANGING;
}

//+------------------------------------------------------------------+
//| ORDER BLOCK DETECTION                                            |
//+------------------------------------------------------------------+
struct OBResult { double strength; int age; bool is_fresh; double level; };
OBResult g_bull_ob[], g_bear_ob[];

void ScanOrderBlocks(ENUM_MARKET_BIAS bias)
{
   ArrayResize(g_bull_ob, 0);
   ArrayResize(g_bear_ob, 0);
   
   double pip = GetPipSize();
   double atr = GetCachedATR();
   if(atr <= 0) return;
   
   double cur_bid = SymbolInfoDouble(InpSymbol, SYMBOL_BID);
   double cur_ask = SymbolInfoDouble(InpSymbol, SYMBOL_ASK);
   double cur = (cur_bid + cur_ask) / 2;
   
   ScanOBTimeframe(InpHTF_TF, pip, atr, cur, bias);
   ScanOBTimeframe(InpEntry_TF, pip, atr, cur, bias);
}

void ScanOBTimeframe(ENUM_TIMEFRAMES tf, double pip, double atr, double cur, ENUM_MARKET_BIAS bias)
{
   int lookback = InpOB_Lookback;
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   int count = CopyRates(InpSymbol, tf, 0, lookback + 5, rates);
   if(count <= 5) return;
   
   double tf_atr = atr;
   
   for(int i = 2; i < count - 2 && i < lookback; i++)
   {
      double impulse = rates[i-1].high - rates[i-1].low;
      bool is_impulse = impulse >= 1.0 * tf_atr;
      
      int ob_age = i;
      if(ob_age < InpOB_MinAge || ob_age > InpOB_MaxAge) continue;
      
      bool is_fresh_bull = cur >= rates[i].low;
      bool is_fresh_bear = cur <= rates[i].high;
      
      // Bullish OB
      if(rates[i].close < rates[i].open && rates[i-1].close > rates[i-1].open && is_impulse && is_fresh_bull)
      {
         double vol_avg = 0;
         int vol_count = 0;
         for(int v = i; v < MathMin(i+10, count) && v >= 0; v++)
         {
            vol_avg += rates[v].tick_volume;
            vol_count++;
         }
         if(vol_count > 0) vol_avg /= vol_count;
         if(vol_avg <= 0) vol_avg = 1;
         
         double vr = MathMin((double)rates[i-1].tick_volume / vol_avg, 4.0);
         bool bias_strong = (bias == BIAS_BULL);
         double age_factor = MathMax(0.5, 1.0 - (ob_age - InpOB_MinAge) / 30.0);
         
         double strength = MathMin(100.0,
            40.0 * MathMin(impulse / (tf_atr + 1e-10), 2.5) / 2.5 * age_factor +
            35.0 * MathMin(vr, 2.0) / 2.0 +
            25.0 * (bias_strong ? 1.0 : 0.3));
         
         int idx = ArraySize(g_bull_ob);
         ArrayResize(g_bull_ob, idx + 1);
         g_bull_ob[idx].strength = strength;
         g_bull_ob[idx].age = ob_age;
         g_bull_ob[idx].is_fresh = true;
         g_bull_ob[idx].level = (rates[i].high + rates[i].low) / 2;
      }
      
      // Bearish OB
      if(rates[i].close > rates[i].open && rates[i-1].close < rates[i-1].open && is_impulse && is_fresh_bear)
      {
         double vol_avg = 0;
         int vol_count = 0;
         for(int v = i; v < MathMin(i+10, count) && v >= 0; v++)
         {
            vol_avg += rates[v].tick_volume;
            vol_count++;
         }
         if(vol_count > 0) vol_avg /= vol_count;
         if(vol_avg <= 0) vol_avg = 1;
         
         double vr = MathMin((double)rates[i-1].tick_volume / vol_avg, 4.0);
         bool bias_strong = (bias == BIAS_BEAR);
         double age_factor = MathMax(0.5, 1.0 - (ob_age - InpOB_MinAge) / 30.0);
         
         double strength = MathMin(100.0,
            40.0 * MathMin(impulse / (tf_atr + 1e-10), 2.5) / 2.5 * age_factor +
            35.0 * MathMin(vr, 2.0) / 2.0 +
            25.0 * (bias_strong ? 1.0 : 0.3));
         
         int idx = ArraySize(g_bear_ob);
         ArrayResize(g_bear_ob, idx + 1);
         g_bear_ob[idx].strength = strength;
         g_bear_ob[idx].age = ob_age;
         g_bear_ob[idx].is_fresh = true;
         g_bear_ob[idx].level = (rates[i].high + rates[i].low) / 2;
      }
   }
}

OBResult GetOBAtPrice(bool is_bull)
{
   OBResult result = {0, 0, false, 0};
   
   double cur = SymbolInfoDouble(InpSymbol, SYMBOL_BID);
   double pip = GetPipSize();
   double buf = InpOB_BufferPips * pip;
   
   OBResult &source[] = is_bull ? g_bull_ob : g_bear_ob;
   
   for(int i = 0; i < ArraySize(source); i++)
   {
      if(source[i].level - buf <= cur && cur <= source[i].level + buf)
      {
         if(result.strength < source[i].strength)
            result = source[i];
      }
   }
   
   return result;
}

//+------------------------------------------------------------------+
//| FAIR VALUE GAP DETECTION                                         |
//+------------------------------------------------------------------+
struct FVGResult { double hi, lo, size_pips; bool is_bull; bool is_retesting; };
FVGResult g_bull_fvg[], g_bear_fvg[];

void ScanFVGs()
{
   ArrayResize(g_bull_fvg, 0);
   ArrayResize(g_bear_fvg, 0);
   
   double cur = SymbolInfoDouble(InpSymbol, SYMBOL_BID);
   double pip = GetPipSize();
   double min_pts = InpFVG_MinPips * pip;
   
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   int count = CopyRates(InpSymbol, InpFVG_TF, 0, InpFVG_MaxAgeBars + 20, rates);
   if(count <= InpFVG_MaxAgeBars) return;
   
   for(int i = 2; i < MathMin(InpFVG_MaxAgeBars + 5, count - 2); i++)
   {
      if(i > InpFVG_MaxAgeBars) continue;
      
      // Bullish FVG
      if(rates[i-2].low > rates[i].high && (rates[i-2].low - rates[i].high) >= min_pts)
      {
         double gap_size = (rates[i-2].low - rates[i].high) / pip;
         bool is_retesting = cur <= rates[i-2].low && cur >= rates[i].high;
         bool not_filled = cur > rates[i].high;
         
         if(is_retesting && not_filled)
         {
            int idx = ArraySize(g_bull_fvg);
            ArrayResize(g_bull_fvg, idx + 1);
            g_bull_fvg[idx].hi = rates[i-2].low;
            g_bull_fvg[idx].lo = rates[i].high;
            g_bull_fvg[idx].size_pips = gap_size;
            g_bull_fvg[idx].is_bull = true;
            g_bull_fvg[idx].is_retesting = true;
         }
      }
      
      // Bearish FVG
      if(rates[i-2].high < rates[i].low && (rates[i].low - rates[i-2].high) >= min_pts)
      {
         double gap_size = (rates[i].low - rates[i-2].high) / pip;
         bool is_retesting = cur >= rates[i-2].high && cur <= rates[i].low;
         bool not_filled = cur < rates[i].low;
         
         if(is_retesting && not_filled)
         {
            int idx = ArraySize(g_bear_fvg);
            ArrayResize(g_bear_fvg, idx + 1);
            g_bear_fvg[idx].hi = rates[i].low;
            g_bear_fvg[idx].lo = rates[i-2].high;
            g_bear_fvg[idx].size_pips = gap_size;
            g_bear_fvg[idx].is_bull = false;
            g_bear_fvg[idx].is_retesting = true;
         }
      }
   }
}

bool IsPriceInFVG(bool is_bull)
{
   double price = SymbolInfoDouble(InpSymbol, SYMBOL_BID);
   FVGResult &source[] = is_bull ? g_bull_fvg : g_bear_fvg;
   
   for(int i = 0; i < ArraySize(source); i++)
   {
      if(source[i].lo <= price && price <= source[i].hi)
         return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| VOLUME SPIKE CHECK                                                |
//+------------------------------------------------------------------+
bool CheckVolumeSpike()
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   int count = CopyRates(InpSymbol, InpEntry_TF, 0, InpVolMA_Period + 5, rates);
   if(count <= InpVolMA_Period) return false;
   
   double vol_avg = 0;
   for(int i = 1; i <= InpVolMA_Period; i++)
      vol_avg += rates[i].tick_volume;
   vol_avg /= InpVolMA_Period;
   
   return vol_avg > 0 && (double)rates[0].tick_volume / vol_avg >= InpVolSpikeMult;
}

//+------------------------------------------------------------------+
//| DIVERGENCE CHECK                                                  |
//+------------------------------------------------------------------+
bool CheckDivergence(bool is_bull)
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   int count = CopyRates(InpSymbol, InpEntry_TF, 0, InpDiv_Lookback + 10, rates);
   if(count <= InpDiv_Lookback + 5) return false;
   
   double close_vals[];
   ArraySetAsSeries(close_vals, true);
   ArrayResize(close_vals, count);
   for(int i = 0; i < count; i++)
      close_vals[i] = rates[i].close;
   
   double highs[], lows[];
   ArraySetAsSeries(highs, true);
   ArraySetAsSeries(lows, true);
   ArrayResize(highs, count);
   ArrayResize(lows, count);
   for(int i = 0; i < count; i++)
   {
      highs[i] = rates[i].high;
      lows[i] = rates[i].low;
   }
   
   double rsi_prev = CalculateRSI(InpRSI_Period, 3, InpEntry_TF);
   double rsi_curr = CalculateRSI(InpRSI_Period, 1, InpEntry_TF);
   double rsi_older = CalculateRSI(InpRSI_Period, 5, InpEntry_TF);
   
   double macd_handle = iMACD(InpSymbol, InpEntry_TF, InpMACD_Fast, InpMACD_Slow, InpMACD_Signal, PRICE_CLOSE);
   double macd1 = iMACD(InpSymbol, InpEntry_TF, InpMACD_Fast, InpMACD_Slow, InpMACD_Signal, 1);
   double macd3 = iMACD(InpSymbol, InpEntry_TF, InpMACD_Fast, InpMACD_Slow, InpMACD_Signal, 3);
   IndicatorRelease(macd_handle);
   
   if(is_bull)
   {
      int l1 = 1, l2 = -1;
      for(int i = 2; i < InpDiv_Lookback && i < count; i++)
      {
         if(lows[i] < lows[l1])
         {
            l2 = l1;
            l1 = i;
         }
      }
      if(l2 < 0) return false;
      double rsi_at_l1 = CalculateRSI(InpRSI_Period, l1, InpEntry_TF);
      double rsi_at_l2 = CalculateRSI(InpRSI_Period, l2, InpEntry_TF);
      return lows[l1] < lows[l2] && rsi_at_l1 > rsi_at_l2 && macd1 > macd3;
   }
   else
   {
      int h1 = 1, h2 = -1;
      for(int i = 2; i < InpDiv_Lookback && i < count; i++)
      {
         if(highs[i] > highs[h1])
         {
            h2 = h1;
            h1 = i;
         }
      }
      if(h2 < 0) return false;
      double rsi_at_h1 = CalculateRSI(InpRSI_Period, h1, InpEntry_TF);
      double rsi_at_h2 = CalculateRSI(InpRSI_Period, h2, InpEntry_TF);
      return highs[h1] > highs[h2] && rsi_at_h1 < rsi_at_h2 && macd1 < macd3;
   }
}

//+------------------------------------------------------------------+
//| MSS (Market Structure Shift) DETECTION                            |
//+------------------------------------------------------------------+
bool DetectMSS(bool is_bull)
{
   return CheckMSSOnTF(InpEntry_TF, is_bull, 20) || CheckMSSOnTF(PERIOD_M1, is_bull, 30);
}

bool CheckMSSOnTF(ENUM_TIMEFRAMES tf, bool is_bull, int lookback)
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   int count = CopyRates(InpSymbol, tf, 0, lookback + 5, rates);
   if(count <= 10) return false;
   
   if(is_bull)
   {
      double recent_lh = -1e10;
      for(int i = 2; i < lookback && i < count - 1; i++)
      {
         if(rates[i].high > rates[i-1].high && rates[i].high > rates[i+1].high)
            recent_lh = MathMax(recent_lh, rates[i].high);
      }
      if(recent_lh == -1e10) return false;
      
      bool broke_now = count > 0 && rates[0].close > recent_lh;
      bool broke_prev = count > 2 && rates[1].close > recent_lh && rates[2].close <= recent_lh;
      return broke_now || broke_prev;
   }
   else
   {
      double recent_hl = 1e10;
      for(int i = 2; i < lookback && i < count - 1; i++)
      {
         if(rates[i].low < rates[i-1].low && rates[i].low < rates[i+1].low)
            recent_hl = MathMin(recent_hl, rates[i].low);
      }
      if(recent_hl == 1e10) return false;
      
      bool broke_now = count > 0 && rates[0].close < recent_hl;
      bool broke_prev = count > 2 && rates[1].close < recent_hl && rates[2].close >= recent_hl;
      return broke_now || broke_prev;
   }
}

//+------------------------------------------------------------------+
//| LIQUIDITY SWEEP DETECTION                                         |
//+------------------------------------------------------------------+
bool DetectLiquiditySweep(bool is_bull)
{
   int lb = InpOB_Lookback / 2;
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   int count = CopyRates(InpSymbol, InpHTF_TF, 0, lb + 5, rates);
   if(count <= lb) return false;
   
   int sweep_bars = 3;
   
   if(is_bull)
   {
      double sw_lo = rates[sweep_bars + 1].low;
      for(int j = sweep_bars + 2; j < lb && j < count; j++)
         sw_lo = MathMin(sw_lo, rates[j].low);
      
      for(int j = 1; j <= sweep_bars && j < count; j++)
      {
         double vol_avg = 0, vol_cnt = 0;
         for(int v = j + 1; v < MathMin(j + 11, count); v++)
         {
            vol_avg += rates[v].tick_volume;
            vol_cnt++;
         }
         if(vol_cnt > 0) vol_avg /= vol_cnt;
         
         if(rates[j].low < sw_lo && rates[j].close > sw_lo && 
            rates[j].close > rates[j].open && vol_avg > 0 && 
            (double)rates[j].tick_volume > 1.3 * vol_avg)
            return true;
      }
   }
   else
   {
      double sw_hi = rates[sweep_bars + 1].high;
      for(int j = sweep_bars + 2; j < lb && j < count; j++)
         sw_hi = MathMax(sw_hi, rates[j].high);
      
      for(int j = 1; j <= sweep_bars && j < count; j++)
      {
         double vol_avg = 0, vol_cnt = 0;
         for(int v = j + 1; v < MathMin(j + 11, count); v++)
         {
            vol_avg += rates[v].tick_volume;
            vol_cnt++;
         }
         if(vol_cnt > 0) vol_avg /= vol_cnt;
         
         if(rates[j].high > sw_hi && rates[j].close < sw_hi && 
            rates[j].close < rates[j].open && vol_avg > 0 && 
            (double)rates[j].tick_volume > 1.3 * vol_avg)
            return true;
      }
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| DISPLACEMENT DETECTION                                            |
//+------------------------------------------------------------------+
struct DispResult { bool detected; ENUM_TRADE_DIRECTION direction; double pips; int bars; double vol_ratio; };
DispResult g_displacement;

void DetectDisplacement(bool is_bull)
{
   g_displacement.detected = false;
   g_displacement.direction = DIRECTION_NONE;
   g_displacement.pips = 0;
   g_displacement.bars = 0;
   g_displacement.vol_ratio = 1.0;
   
   if(!InpUseDisplacement)
   {
      g_displacement.detected = true;
      return;
   }
   
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   int count = CopyRates(InpSymbol, InpEntry_TF, 0, InpDisp_Lookback + 10, rates);
   if(count <= InpDisp_Lookback) return;
   
   double vol_avg = 0;
   for(int i = 5; i < 20 && i < count; i++)
      vol_avg += rates[i].tick_volume;
   vol_avg /= MathMin(15, count - 5);
   if(vol_avg <= 0) vol_avg = 1;
   
   double pip = GetPipSize();
   
   for(int i = 1; i < MathMin(6, count); i++)
   {
      double vol_ratio = (double)rates[i].tick_volume / vol_avg;
      if(vol_ratio < InpDisp_MinVolMult) continue;
      
      if(is_bull)
      {
         int min_bars = InpDisp_MinBars;
         if(i + min_bars < count)
         {
            double prev_hi = rates[i+1].high;
            double prev_lo = rates[i+1].low;
            for(int b = 1; b <= min_bars && i+1+b < count; b++)
            {
               prev_hi = MathMax(prev_hi, rates[i+1+b].high);
               prev_lo = MathMin(prev_lo, rates[i+1+b].low);
            }
            
            if(rates[i].close > prev_hi && rates[i].open < prev_lo && 
               rates[i].close > rates[i+1].open && vol_ratio >= InpDisp_MinVolMult)
            {
               g_displacement.detected = true;
               g_displacement.direction = DIRECTION_BUY;
               g_displacement.bars = min_bars;
               g_displacement.pips = (rates[i].high - rates[i].low) / pip;
               g_displacement.vol_ratio = vol_ratio;
               return;
            }
         }
      }
      else
      {
         int min_bars = InpDisp_MinBars;
         if(i + min_bars < count)
         {
            double prev_hi = rates[i+1].high;
            double prev_lo = rates[i+1].low;
            for(int b = 1; b <= min_bars && i+1+b < count; b++)
            {
               prev_hi = MathMax(prev_hi, rates[i+1+b].high);
               prev_lo = MathMin(prev_lo, rates[i+1+b].low);
            }
            
            if(rates[i].close < prev_lo && rates[i].open > prev_hi && 
               rates[i].close < rates[i+1].open && vol_ratio >= InpDisp_MinVolMult)
            {
               g_displacement.detected = true;
               g_displacement.direction = DIRECTION_SELL;
               g_displacement.bars = min_bars;
               g_displacement.pips = (rates[i].high - rates[i].low) / pip;
               g_displacement.vol_ratio = vol_ratio;
               return;
            }
         }
      }
   }
   
   g_displacement.detected = true;
}

//+------------------------------------------------------------------+
//| BREAKER BLOCK DETECTION                                           |
//+------------------------------------------------------------------+
struct BBResult { bool detected; double strength; };
BBResult g_breaker_block;

void DetectBreakerBlock(bool is_bull)
{
   g_breaker_block.detected = false;
   g_breaker_block.strength = 0;
   
   if(!InpUseBreakerBlock)
   {
      g_breaker_block.detected = true;
      return;
   }
   
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   int count = CopyRates(InpSymbol, InpEntry_TF, 0, InpBB_Lookback + 10, rates);
   if(count <= 20) return;
   
   double pip = GetPipSize();
   double cur = SymbolInfoDouble(InpSymbol, SYMBOL_BID);
   
   double swing_highs[], swing_lows[];
   int sh_count = 0, sl_count = 0;
   ArrayResize(swing_highs, 0);
   ArrayResize(swing_lows, 0);
   
   for(int i = 3; i < count - 3; i++)
   {
      if(rates[i].high > rates[i-1].high && rates[i].high > rates[i+1].high &&
         rates[i].high > rates[i-2].high && rates[i].high > rates[i+2].high)
      {
         ArrayResize(swing_highs, sh_count + 1);
         swing_highs[sh_count] = rates[i].high;
         sh_count++;
      }
      if(rates[i].low < rates[i-1].low && rates[i].low < rates[i+1].low &&
         rates[i].low < rates[i-2].low && rates[i].low < rates[i+2].low)
      {
         ArrayResize(swing_lows, sl_count + 1);
         swing_lows[sl_count] = rates[i].low;
         sl_count++;
      }
   }
   
   if(is_bull)
   {
      for(int i = 0; i < MathMin(5, sl_count); i++)
      {
         double sl_price = swing_lows[i];
         bool broken = false, returned = false;
         
         for(int j = 1; j < i; j++)
         {
            if(rates[j].low < sl_price) broken = true;
            if(MathAbs(rates[j].close - sl_price) < 5 * pip) returned = true;
         }
         
         if(broken && returned)
         {
            double dist = sl_price > cur ? (sl_price - cur) / pip : 0;
            if(dist > 0 && dist < 30)
            {
               g_breaker_block.detected = true;
               g_breaker_block.strength = MathMin(100, 50 + 30 * (1 - dist / 30));
               return;
            }
         }
      }
   }
   else
   {
      for(int i = 0; i < MathMin(5, sh_count); i++)
      {
         double sh_price = swing_highs[i];
         bool broken = false, returned = false;
         
         for(int j = 1; j < i; j++)
         {
            if(rates[j].high > sh_price) broken = true;
            if(MathAbs(rates[j].close - sh_price) < 5 * pip) returned = true;
         }
         
         if(broken && returned)
         {
            double dist = cur > sh_price ? (cur - sh_price) / pip : 0;
            if(dist > 0 && dist < 30)
            {
               g_breaker_block.detected = true;
               g_breaker_block.strength = MathMin(100, 50 + 30 * (1 - dist / 30));
               return;
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| VOLUME ABSORPTION DETECTION                                       |
//+------------------------------------------------------------------+
struct AbsResult { bool detected; ENUM_TRADE_DIRECTION direction; double ratio; };
AbsResult g_absorption;

void CheckAbsorption(bool is_bull)
{
   g_absorption.detected = false;
   g_absorption.direction = DIRECTION_NONE;
   g_absorption.ratio = 1.0;
   
   if(!InpUseAbsorption)
   {
      g_absorption.detected = true;
      return;
   }
   
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   int count = CopyRates(InpSymbol, InpEntry_TF, 0, InpAbsorption_Lookback + 10, rates);
   if(count <= InpAbsorption_Lookback) return;
   
   double vol_avg = 0;
   for(int i = 5; i < count; i++)
      vol_avg += rates[i].tick_volume;
   vol_avg /= MathMax(1, count - 5);
   if(vol_avg <= 0) return;
   
   double pip = GetPipSize();
   
   for(int i = 1; i < MathMin(10, count); i++)
   {
      double vol_ratio = (double)rates[i].tick_volume / vol_avg;
      double price_range = (rates[i].high - rates[i].low) / pip;
      
      if(vol_ratio >= InpAbsorption_VolMult && price_range < 5)
      {
         if(is_bull && vol_ratio >= InpAbsorption_VolMult * 1.5)
         {
            g_absorption.detected = true;
            g_absorption.direction = DIRECTION_BUY;
            g_absorption.ratio = vol_ratio;
            return;
         }
         else if(!is_bull && vol_ratio >= InpAbsorption_VolMult * 1.5)
         {
            g_absorption.detected = true;
            g_absorption.direction = DIRECTION_SELL;
            g_absorption.ratio = vol_ratio;
            return;
         }
      }
   }
}

//+------------------------------------------------------------------+
//| SESSION MOMENTUM DETECTION                                        |
//+------------------------------------------------------------------+
struct MomResult { ENUM_TRADE_DIRECTION direction; double strength; int consecutive; int total; };
MomResult g_session_momentum;

void GetSessionMomentum(bool is_bull)
{
   g_session_momentum.direction = DIRECTION_NONE;
   g_session_momentum.strength = 0;
   g_session_momentum.consecutive = 0;
   g_session_momentum.total = 0;
   
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   int count = CopyRates(InpSymbol, InpEntry_TF, 0, InpSessionMomBars + 5, rates);
   if(count <= InpSessionMomBars) return;
   
   int bull_bars = 0, bear_bars = 0;
   
   for(int i = 0; i < MathMin(InpSessionMomBars, count); i++)
   {
      if(rates[i].close > rates[i].open) bull_bars++;
      else if(rates[i].close < rates[i].open) bear_bars++;
   }
   
   int total = bull_bars + bear_bars;
   if(total == 0) return;
   
   if(bull_bars > bear_bars)
   {
      g_session_momentum.direction = DIRECTION_BUY;
      g_session_momentum.consecutive = bull_bars;
   }
   else if(bear_bars > bull_bars)
   {
      g_session_momentum.direction = DIRECTION_SELL;
      g_session_momentum.consecutive = bear_bars;
   }
   
   g_session_momentum.total = total;
   g_session_momentum.strength = (MathAbs(bull_bars - bear_bars) / (double)total) * 100;
}

//+------------------------------------------------------------------+
//| DXY CORRELATION CHECK                                            |
//+------------------------------------------------------------------+
bool CheckDXY(ENUM_TRADE_DIRECTION direction)
{
   if(!InpUseDXY) return true;
   
   string sym = InpSymbol;
   bool needs = false;
   if(StringFind(sym, "EUR") >= 0 || StringFind(sym, "GBP") >= 0 || 
      StringFind(sym, "AUD") >= 0 || StringFind(sym, "NZD") >= 0 ||
      StringFind(sym, "XAU") >= 0 || StringFind(sym, "GOLD") >= 0)
      needs = true;
   
   bool usd_b = StringFind(sym, "USD") >= 0 && !needs;
   if(!needs && !usd_b) return true;
   
   if(!SymbolSelect(InpDXY_Symbol, true)) return true;
   
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   int count = CopyRates(InpDXY_Symbol, InpHTF_TF, 0, InpDXY_Lookback + 2, rates);
   if(count <= 5) return true;
   
   double close_vals[];
   ArraySetAsSeries(close_vals, true);
   ArrayResize(close_vals, count);
   for(int i = 0; i < count; i++)
      close_vals[i] = rates[i].close;
   
   double slope = LinearRegressionSlope(close_vals);
   
   if(needs)
      return (direction == DIRECTION_BUY) ? slope < 0 : slope > 0;
   else
      return (direction == DIRECTION_BUY) ? slope > 0 : slope < 0;
}

//+------------------------------------------------------------------+
//| DELTA CHECK                                                       |
//+------------------------------------------------------------------+
bool CheckDelta(ENUM_TRADE_DIRECTION direction)
{
   MqlTick ticks[];
   int count = CopyTicks(InpSymbol, ticks, COPY_TICKS_TRADE, 0, InpOB_Lookback * 10);
   if(count <= 10) return true;
   
   double buy_vol = 0, sell_vol = 0;
   for(int i = 0; i < count; i++)
   {
      if((ticks[i].flags & TICK_FLAG_BUY) != 0)
         buy_vol += ticks[i].volume;
      if((ticks[i].flags & TICK_FLAG_SELL) != 0)
         sell_vol += ticks[i].volume;
   }
   
   double total = buy_vol + sell_vol;
   if(total <= 0) return true;
   
   double ratio = buy_vol / total;
   double min_r = 0.55;
   
   if(direction == DIRECTION_BUY)
      return ratio >= min_r && buy_vol > sell_vol;
   else
      return ratio <= (1 - min_r) && sell_vol > buy_vol;
}

//+------------------------------------------------------------------+
//| VOLUME PROFILE                                                   |
//+------------------------------------------------------------------+
void BuildVolumeProfile()
{
   g_vp.is_valid = false;
   
   if(!InpUseVP) { g_vp.is_valid = true; return; }
   
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   int count = CopyRates(InpSymbol, InpEntry_TF, 0, InpVP_Bars, rates);
   if(count <= 10) return;
   
   double hi_max = rates[0].high, lo_min = rates[0].low;
   for(int i = 1; i < count; i++)
   {
      hi_max = MathMax(hi_max, rates[i].high);
      lo_min = MathMin(lo_min, rates[i].low);
   }
   
   if(hi_max <= lo_min) return;
   
   double bucket_size = (hi_max - lo_min) / InpVP_Buckets;
   double vols[];
   ArrayResize(vols, InpVP_Buckets);
   ArrayInitialize(vols, 0);
   
   for(int i = 0; i < count; i++)
   {
      double bar_range = rates[i].high - rates[i].low;
      if(bar_range <= 0) continue;
      
      int lo_idx = (int)MathMax(0, MathMin(InpVP_Buckets - 1, (rates[i].low - lo_min) / bucket_size));
      int hi_idx = (int)MathMax(0, MathMin(InpVP_Buckets - 1, (rates[i].high - lo_min) / bucket_size));
      
      for(int b = lo_idx; b <= hi_idx; b++)
      {
         double blo = lo_min + b * bucket_size;
         double bhi = blo + bucket_size;
         double ovlp = (MathMin(rates[i].high, bhi) - MathMax(rates[i].low, blo)) / bar_range;
         if(ovlp > 0)
            vols[b] += rates[i].tick_volume * ovlp;
      }
   }
   
   int poc_idx = 0;
   double max_vol = vols[0];
   for(int i = 1; i < InpVP_Buckets; i++)
   {
      if(vols[i] > max_vol)
      {
         max_vol = vols[i];
         poc_idx = i;
      }
   }
   
   double total_vol = 0;
   for(int i = 0; i < InpVP_Buckets; i++)
      total_vol += vols[i];
   
   double target = total_vol * InpVP_ValueAreaPct / 100.0;
   double acc = vols[poc_idx];
   int vhi = poc_idx, vlo = poc_idx;
   
   while(acc < target && (vhi < InpVP_Buckets - 1 || vlo > 0))
   {
      double n_hi = vhi < InpVP_Buckets - 1 ? vols[vhi + 1] : 0;
      double n_lo = vlo > 0 ? vols[vlo - 1] : 0;
      
      if(n_hi >= n_lo && vhi < InpVP_Buckets - 1)
      { vhi++; acc += vols[vhi]; }
      else if(vlo > 0)
      { vlo--; acc += vols[vlo]; }
      else if(vhi < InpVP_Buckets - 1)
      { vhi++; acc += vols[vhi]; }
      else break;
   }
   
   g_vp.poc = lo_min + (poc_idx + 0.5) * bucket_size;
   g_vp.vah = lo_min + (vhi + 1.0) * bucket_size;
   g_vp.val = lo_min + vlo * bucket_size;
   g_vp.is_valid = true;
}

bool CheckVPZone(ENUM_TRADE_DIRECTION direction)
{
   if(!InpUseVP || !g_vp.is_valid) return true;
   
   double price = SymbolInfoDouble(InpSymbol, SYMBOL_BID);
   double pip = GetPipSize();
   double poc_buf = InpVP_POC_BufferPips * pip;
   
   if(MathAbs(price - g_vp.poc) <= poc_buf) return false;
   if(direction == DIRECTION_BUY && price > g_vp.vah) return false;
   if(direction == DIRECTION_SELL && price < g_vp.val) return false;
   
   return true;
}

//+------------------------------------------------------------------+
//| VIX CHECK                                                         |
//+------------------------------------------------------------------+
double GetVIX()
{
   if(!InpUseVIX) return 0;
   
   if(!SymbolSelect(InpVIX_Symbol, true)) return 0;
   
   MqlTick tick;
   if(!SymbolInfoTick(InpVIX_Symbol, tick)) return 0;
   if(tick.bid <= 0) return 0;
   if(tick.bid > 200.0) return 0;
   
   return tick.bid;
}

bool IsVIXClear()
{
   double vix = GetVIX();
   return vix <= 0 || vix < InpVIX_MaxLevel;
}

//+------------------------------------------------------------------+
//| KILL ZONE DETECTION (DST-AWARE)                                   |
//+------------------------------------------------------------------+
bool IsInKillZone(string &kz_type)
{
   datetime utc_now = TimeCurrent();
   MqlDateTime st;
   TimeToStruct(utc_now, st);
   int utc_hour = st.hour;
   
   bool uk_dst = false;
   if(3 < st.mon && st.mon < 10) uk_dst = true;
   else if(st.mon == 3)
   {
      int days_to_end = st.day - (st.day_of_week);
      if(days_to_end >= 25) uk_dst = true;
   }
   else if(st.mon == 10)
   {
      int days_to_end = st.day - (st.day_of_week);
      if(days_to_end < 25) uk_dst = true;
   }
   
   int uk_hour = (utc_hour + (uk_dst ? 1 : 0)) % 24;
   int est_offset = (3 < st.mon && st.mon < 11) ? -4 : -5;
   int est_hour = (utc_hour + est_offset + 24) % 24;
   
   bool london_kz = uk_hour >= InpLondonKZ_Start && uk_hour < InpLondonKZ_End;
   bool ny_kz = est_hour >= InpNYKZ_Start && est_hour < InpNYKZ_End;
   
   if(london_kz) { kz_type = "LONDON"; return true; }
   else if(ny_kz) { kz_type = "NY"; return true; }
   else { kz_type = ""; return false; }
}

//+------------------------------------------------------------------+
//| ENGINE 1: SMC RESULT STRUCT                                       |
//+------------------------------------------------------------------+
struct SMCResult
{
   bool     fired;
   ENUM_TRADE_DIRECTION direction;
   ENUM_FILTER_FAILURE block_reason;
   
   int      smc_score;
   bool     has_ob;
   bool     has_fvg;
   bool     has_vol_spike;
   bool     has_divergence;
   bool     has_adx;
   bool     has_adx_strong;
   bool     has_liq_sweep;
   double   ob_strength;
   bool     has_displacement;
   bool     has_breaker_block;
   bool     has_absorption;
   bool     has_session_momentum;
   double   momentum_strength;
   ENUM_TRADE_DIRECTION momentum_direction;
   
   bool     in_kill_zone;
   string   kill_zone_type;
   bool     dxy_confirmed;
   bool     delta_positive;
   bool     vp_zone_valid;
   bool     vix_clear;
   double   vix_level;
   bool     vix_caution;
   
   double   confidence;
   double   adx_value;
   double   spread_pips;
   
   double   sl_price;
   double   tp1_price;
   double   tp2_price;
   
   double   nearest_ob_dist;
   double   nearest_ob_str;
};

SMCResult g_smc_result;

//+------------------------------------------------------------------+
//| ENGINE 1: MAIN EVALUATOR                                          |
//+------------------------------------------------------------------+
SMCResult EvaluateEngine1()
{
   SMCResult r;
   r.fired = false;
   r.direction = DIRECTION_NONE;
   r.block_reason = FILTER_PASS;
   
   r.spread_pips = GetSpreadPips();
   r.vix_level = GetVIX();
   r.vix_clear = IsVIXClear();
   r.vix_caution = r.vix_level > 0 && r.vix_level < InpVIX_MaxLevel && r.vix_level >= InpVIX_CautionLevel;
   
   ENUM_MARKET_BIAS bias1 = DetectBias(InpHTF_TF, 30);
   ENUM_MARKET_BIAS bias2 = DetectBias(InpHTF_TF2, 20);
   bool bull_bias = bias1 == BIAS_BULL || bias2 == BIAS_BULL;
   bool bear_bias = bias1 == BIAS_BEAR || bias2 == BIAS_BEAR;
   bool check_bull = bull_bias && (!bear_bias || bias1 == BIAS_BULL) || (!bull_bias && !bear_bias);
   ENUM_TRADE_DIRECTION tent_dir = check_bull ? DIRECTION_BUY : DIRECTION_SELL;
   
   ScanOrderBlocks(bias1);
   ScanFVGs();
   BuildVolumeProfile();
   
   if(bull_bias || bear_bias)
   {
      OBResult ob = GetOBAtPrice(check_bull);
      r.has_ob = ob.strength >= InpOB_MinStrength && ob.is_fresh;
      r.ob_strength = ob.strength;
      r.nearest_ob_dist = ob.strength > 0 ? 5 : 0;
      r.nearest_ob_str = ob.strength;
      
      r.has_fvg = IsPriceInFVG(check_bull);
      r.has_vol_spike = CheckVolumeSpike();
      r.has_divergence = CheckDivergence(check_bull);
      r.adx_value = GetCachedADX();
      r.has_adx = r.adx_value >= InpADX_Min;
      r.has_adx_strong = r.adx_value >= InpADX_Strong;
      r.has_liq_sweep = DetectLiquiditySweep(check_bull);
      
      DetectDisplacement(check_bull);
      r.has_displacement = g_displacement.detected;
      
      DetectBreakerBlock(check_bull);
      r.has_breaker_block = g_breaker_block.detected;
      
      CheckAbsorption(check_bull);
      r.has_absorption = g_absorption.detected;
      
      GetSessionMomentum(check_bull);
      r.has_session_momentum = g_session_momentum.direction == tent_dir && g_session_momentum.strength >= 70;
      r.momentum_strength = g_session_momentum.strength;
      r.momentum_direction = g_session_momentum.direction;
      
      r.smc_score = 0;
      if(r.has_ob) r.smc_score++;
      if(r.has_fvg) r.smc_score++;
      if(r.has_vol_spike) r.smc_score++;
      if(r.has_divergence) r.smc_score++;
      if(r.has_adx) r.smc_score++;
   }
   else
   {
      r.adx_value = GetCachedADX();
      r.has_adx = r.adx_value >= InpADX_Min;
      r.has_adx_strong = r.adx_value >= InpADX_Strong;
      r.has_vol_spike = CheckVolumeSpike();
      r.smc_score = 0;
   }
   
   r.dxy_confirmed = CheckDXY(tent_dir);
   r.delta_positive = CheckDelta(tent_dir);
   r.vp_zone_valid = CheckVPZone(tent_dir);
   
   double score = 0;
   if(r.has_ob) score += 18.0 * r.ob_strength / 100.0;
   if(r.has_fvg) score += 12.0;
   if(r.has_vol_spike) score += 10.0;
   if(r.has_divergence) score += 12.0;
   if(r.has_adx) score += 12.0 * MathMin(r.adx_value / 50.0, 1.0);
   if(r.dxy_confirmed) score += 8.0;
   if(r.delta_positive) score += 6.0;
   if(r.vp_zone_valid) score += 5.0;
   if(r.has_liq_sweep) score += 7.0;
   if(r.has_displacement) score += 8.0;
   if(r.has_breaker_block) score += 6.0;
   if(r.has_absorption) score += 4.0;
   if(r.has_session_momentum) score += 4.0;
   
   r.confidence = MathMin(score, 100.0);
   
   string kz_type;
   r.in_kill_zone = IsInKillZone(kz_type);
   r.kill_zone_type = kz_type;
   if(!r.in_kill_zone) { r.block_reason = FILTER_KILL_ZONE; return r; }
   
   if(!r.vix_clear) { r.block_reason = FILTER_VIX; return r; }
   
   double max_spread = InpMaxSpreadPtsE1;
   if(r.in_kill_zone) max_spread += InpKZ_SpreadTol;
   if(r.spread_pips * 10 > max_spread) { r.block_reason = FILTER_SPREAD; return r; }
   
   if(!bull_bias && !bear_bias) { r.block_reason = FILTER_SMC; return r; }
   
   if(r.smc_score < InpMinConfirmations) { r.block_reason = FILTER_SMC; return r; }
   
   if(!DetectMSS(check_bull)) { r.block_reason = FILTER_SMC; return r; }
   
   if(!r.has_session_momentum && r.momentum_direction != DIRECTION_NONE && r.momentum_direction != tent_dir)
   { r.block_reason = FILTER_SMC; return r; }
   
   if(!r.dxy_confirmed) { r.block_reason = FILTER_DXY_CORR; return r; }
   if(!r.vp_zone_valid) { r.block_reason = FILTER_VOL_PROFILE; return r; }
   if(!r.delta_positive) { r.block_reason = FILTER_DELTA; return r; }
   
   if(InpUseDisplacement && !r.has_displacement) { r.block_reason = FILTER_SMC; return r; }
   if(InpUseBreakerBlock && !r.has_breaker_block) { r.block_reason = FILTER_SMC; return r; }
   
   double atr = GetCachedATR();
   double ask = SymbolInfoDouble(InpSymbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(InpSymbol, SYMBOL_BID);
   double entry = check_bull ? ask : bid;
   
   if(check_bull)
   {
      r.sl_price = entry - atr * InpATR_SL_Mult;
      r.tp1_price = entry + (entry - r.sl_price) * InpE1_TP1_RR;
      r.tp2_price = entry + (entry - r.sl_price) * InpE1_TP2_RR;
   }
   else
   {
      r.sl_price = entry + atr * InpATR_SL_Mult;
      r.tp1_price = entry - (r.sl_price - entry) * InpE1_TP1_RR;
      r.tp2_price = entry - (r.sl_price - entry) * InpE1_TP2_RR;
   }
   
   double rr = MathAbs(r.tp2_price - entry) / (MathAbs(r.sl_price - entry) + 1e-10);
   if(rr < InpE1_TP1_RR) { r.block_reason = FILTER_LOW_RR; return r; }
   
   r.fired = true;
   r.direction = check_bull ? DIRECTION_BUY : DIRECTION_SELL;
   return r;
}

//+------------------------------------------------------------------+
//| ENGINE 2: MEAN REVERSION RESULT STRUCT                            |
//+------------------------------------------------------------------+
struct RevResult
{
   bool     fired;
   ENUM_TRADE_DIRECTION direction;
   ENUM_FILTER_FAILURE block_reason;
   
   bool     c1_range_valid;
   bool     c2_sweep;
   bool     c3_vol_exhaust;
   bool     c4_rejection;
   bool     c5_rsi_extreme;
   
   double   sweep_level;
   double   sl_price;
   double   tp_price;
   double   entry_price;
   double   confidence;
   double   vwap;
   double   spread_pips;
};

//+------------------------------------------------------------------+
//| ENGINE 2: ASIA RANGE BUILD                                        |
//+------------------------------------------------------------------+
void BuildAsiaRange()
{
   datetime today = GetTodayMidnightUTC();
   
   if(g_asia_box.is_valid && g_asia_box.built_date == today)
   {
      int utc_h = GetUTC_Hour();
      if(!(utc_h == InpAsiaOpen && GetHour() < 10))
         return;
   }
   
   g_asia_box.is_valid = false;
   g_asia_box.hi_swept = false;
   g_asia_box.lo_swept = false;
   
   int end_h = InpAsiaOpen + InpAsiaRangeHours;
   
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   int count = CopyRates(InpSymbol, InpE2_TF, 0, 300, rates);
   if(count <= 0) return;
   
   double hi_val = 0, lo_val = 0;
   int valid_count = 0;
   
   for(int i = 0; i < count; i++)
   {
      datetime t = rates[i].time - InpGMT_Offset * 3600;
      MqlDateTime st;
      TimeToStruct(t, st);
      
      if(t >= today && st.hour >= InpAsiaOpen && st.hour < end_h)
      {
         if(valid_count == 0)
         {
            hi_val = rates[i].high;
            lo_val = rates[i].low;
         }
         else
         {
            hi_val = MathMax(hi_val, rates[i].high);
            lo_val = MathMin(lo_val, rates[i].low);
         }
         valid_count++;
      }
   }
   
   if(valid_count < 6) return;
   
   double pip = GetPipSize();
   double size = (hi_val - lo_val) / pip;
   
   if(size < InpE2_MinAsiaRange) return;
   
   double avg_candle = 0;
   int candle_count = 0;
   for(int i = 0; i < count && candle_count < valid_count; i++)
   {
      datetime t = rates[i].time - InpGMT_Offset * 3600;
      MqlDateTime st;
      TimeToStruct(t, st);
      if(t >= today && st.hour >= InpAsiaOpen && st.hour < end_h)
      {
         avg_candle += (rates[i].high - rates[i].low) / pip;
         candle_count++;
      }
   }
   if(candle_count > 0) avg_candle /= candle_count;
   if(avg_candle > size / 2) return;
   
   g_asia_box.hi = hi_val;
   g_asia_box.lo = lo_val;
   g_asia_box.mid = (hi_val + lo_val) / 2;
   g_asia_box.size_pips = size;
   g_asia_box.built_date = today;
   g_asia_box.is_valid = true;
}

//+------------------------------------------------------------------+
//| ENGINE 2: SWEEP DETECTION                                        |
//+------------------------------------------------------------------+
struct SweepEvent { bool detected; ENUM_TRADE_DIRECTION direction; double price; double bb_level; int bar_idx; };
SweepEvent g_sweep_event;

void DetectSweep()
{
   g_sweep_event.detected = false;
   g_sweep_event.direction = DIRECTION_NONE;
   g_sweep_event.price = 0;
   g_sweep_event.bb_level = 0;
   g_sweep_event.bar_idx = 0;
   
   if(!g_asia_box.is_valid) return;
   
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   int count = CopyRates(InpSymbol, InpE2_TF, 0, InpE2_RejectionBars + 5, rates);
   if(count <= InpE2_RejectionBars + 3) return;
   
   double bb_up[], bb_mid[], bb_lo[];
   CalculateBB(bb_up, bb_mid, bb_lo, InpE2_BB_Period, InpE2_BB_StdDev, InpE2_RejectionBars + 4, InpE2_TF);
   
   double pip = GetPipSize();
   double min_sw = InpE2_SweepMinPips * pip;
   
   for(int i = 1; i <= InpE2_RejectionBars && i < count; i++)
   {
      if(i >= ArraySize(bb_up) || i >= ArraySize(bb_lo)) continue;
      
      if(rates[i].high > g_asia_box.hi + min_sw && 
         bb_up[i] > 0 && rates[i].high > bb_up[i] &&
         rates[i].close <= g_asia_box.hi && !g_asia_box.hi_swept)
      {
         g_asia_box.hi_swept = true;
         g_sweep_event.detected = true;
         g_sweep_event.direction = DIRECTION_SELL;
         g_sweep_event.price = g_asia_box.hi;
         g_sweep_event.bb_level = bb_up[i];
         g_sweep_event.bar_idx = i;
         return;
      }
      
      if(rates[i].low < g_asia_box.lo - min_sw && 
         bb_lo[i] > 0 && rates[i].low < bb_lo[i] &&
         rates[i].close >= g_asia_box.lo && !g_asia_box.lo_swept)
      {
         g_asia_box.lo_swept = true;
         g_sweep_event.detected = true;
         g_sweep_event.direction = DIRECTION_BUY;
         g_sweep_event.price = g_asia_box.lo;
         g_sweep_event.bb_level = bb_lo[i];
         g_sweep_event.bar_idx = i;
         return;
      }
   }
}

//+------------------------------------------------------------------+
//| ENGINE 2: VOLUME EXHAUSTION                                       |
//+------------------------------------------------------------------+
bool CheckVolExhaustion(int sweep_bar)
{
   int safe_bar = MathMax(1, sweep_bar);
   
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   int count = CopyRates(InpSymbol, InpE2_TF, 0, InpE2_BB_Period + safe_bar + 5, rates);
   if(count <= InpE2_BB_Period + 3) return false;
   
   double vol_avg = 0;
   for(int i = safe_bar + 1; i <= safe_bar + InpE2_BB_Period && i < count; i++)
      vol_avg += rates[i].tick_volume;
   vol_avg /= InpE2_BB_Period;
   
   if(vol_avg <= 0) return false;
   return (double)rates[safe_bar].tick_volume < InpE2_VolExhaust * vol_avg;
}

//+------------------------------------------------------------------+
//| ENGINE 2: REJECTION DETECTION                                     |
//+------------------------------------------------------------------+
bool DetectRejection(ENUM_TRADE_DIRECTION direction)
{
   return CheckRejectionTF(InpE2_TF, direction, InpE2_RejectionBars) ||
          CheckRejectionTF(InpE2_ConfirmTF, direction, InpE2_RejectionBars + 1);
}

bool CheckRejectionTF(ENUM_TIMEFRAMES tf, ENUM_TRADE_DIRECTION direction, int lookback)
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   int count = CopyRates(InpSymbol, tf, 0, lookback + 5, rates);
   if(count <= lookback + 2) return false;
   
   double pt = SymbolInfoDouble(InpSymbol, SYMBOL_POINT);
   
   for(int i = 1; i <= lookback && i < count - 1; i++)
   {
      double total = rates[i].high - rates[i].low;
      if(total < pt * 2) continue;
      
      double up_wick = rates[i].high - MathMax(rates[i].close, rates[i].open);
      double dn_wick = MathMin(rates[i].close, rates[i].open) - rates[i].low;
      
      if(direction == DIRECTION_BUY)
      {
         if(dn_wick / total * 100 >= InpE2_PinbarWickPct && rates[i].close > rates[i].open)
            return true;
      }
      else
      {
         if(up_wick / total * 100 >= InpE2_PinbarWickPct && rates[i].close < rates[i].open)
            return true;
      }
      
      if(i + 1 < count)
      {
         double prev_body = MathAbs(rates[i+1].close - rates[i+1].open);
         if(prev_body > pt)
         {
            bool bull_eng = direction == DIRECTION_BUY && rates[i].close > rates[i].open &&
                           rates[i].open < rates[i+1].close && rates[i].close > rates[i+1].open;
            bool bear_eng = direction == DIRECTION_SELL && rates[i].close < rates[i].open &&
                           rates[i].open > rates[i+1].close && rates[i].close < rates[i+1].open;
            if(bull_eng || bear_eng) return true;
         }
      }
      
      if(g_asia_box.is_valid && direction == DIRECTION_BUY)
      {
         if(rates[i].low < g_asia_box.lo && rates[i].close > g_asia_box.lo && 
            i > 1 && rates[i-1].close > rates[i].close)
            return true;
      }
      else if(g_asia_box.is_valid)
      {
         if(rates[i].high > g_asia_box.hi && rates[i].close < g_asia_box.hi &&
            i > 1 && rates[i-1].close < rates[i].close)
            return true;
      }
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| ENGINE 2: RSI EXTREME CHECK                                       |
//+------------------------------------------------------------------+
bool CheckRSIExtreme(ENUM_TRADE_DIRECTION direction, int sweep_bar)
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   int count = CopyRates(InpSymbol, InpE2_TF, 0, sweep_bar + 10, rates);
   if(count <= sweep_bar + 5) return false;
   
   double rsi_sw = CalculateRSI(InpRSI_Period, sweep_bar, InpE2_TF);
   double rsi_now = CalculateRSI(InpRSI_Period, 0, InpE2_TF);
   
   if(direction == DIRECTION_BUY)
   {
      bool was_os = rsi_sw <= InpE2_RSI_OS || rsi_now <= InpE2_RSI_OS + 8;
      double rsi_prev = CalculateRSI(InpRSI_Period, 1, InpE2_TF);
      bool rising = rsi_now > rsi_prev;
      return was_os && rising;
   }
   else
   {
      bool was_ob = rsi_sw >= InpE2_RSI_OB || rsi_now >= InpE2_RSI_OB - 8;
      double rsi_prev = CalculateRSI(InpRSI_Period, 1, InpE2_TF);
      bool falling = rsi_now < rsi_prev;
      return was_ob && falling;
   }
}

//+------------------------------------------------------------------+
//| ENGINE 2: VWAP/TP COMPUTATION                                     |
//+------------------------------------------------------------------+
double ComputeTP(ENUM_TRADE_DIRECTION direction, double entry)
{
   double pip = GetPipSize();
   datetime today = GetTodayMidnightUTC();
   
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   int count = CopyRates(InpSymbol, InpE2_TF, 0, InpE2_VWAP_Bars, rates);
   
   if(count > 5)
   {
      double tp3_sum = 0, vol_sum = 0;
      int valid = 0;
      
      for(int i = 0; i < count; i++)
      {
         datetime t = rates[i].time - InpGMT_Offset * 3600;
         if(t >= today)
         {
            tp3_sum += (rates[i].high + rates[i].low + rates[i].close) / 3.0 * rates[i].tick_volume;
            vol_sum += rates[i].tick_volume;
            valid++;
         }
      }
      
      if(vol_sum > 0 && valid > 3)
      {
         double vwap = tp3_sum / vol_sum;
         double dist = MathAbs(vwap - entry) / pip;
         bool side_ok = (direction == DIRECTION_BUY && vwap > entry) || 
                       (direction == DIRECTION_SELL && vwap < entry);
         if(vwap > 0 && dist >= InpE2_TP_MinPips && dist <= InpE2_TP_MaxPips && side_ok)
         {
            g_vp.poc = vwap;
            return vwap;
         }
      }
      
      double ma20 = CalculateSMA(20, 0, InpE2_TF);
      if(ma20 > 0)
      {
         double dist = MathAbs(ma20 - entry) / pip;
         bool side_ok = (direction == DIRECTION_BUY && ma20 > entry) ||
                       (direction == DIRECTION_SELL && ma20 < entry);
         if(dist >= InpE2_TP_MinPips && dist <= InpE2_TP_MaxPips && side_ok)
            return ma20;
      }
   }
   
   double delta = InpE2_TP_MinPips * pip;
   return direction == DIRECTION_BUY ? entry + delta : entry - delta;
}

//+------------------------------------------------------------------+
//| ENGINE 2: MAIN EVALUATOR                                          |
//+------------------------------------------------------------------+
RevResult EvaluateEngine2()
{
   RevResult r;
   r.fired = false;
   r.direction = DIRECTION_NONE;
   r.block_reason = FILTER_PASS;
   
   r.spread_pips = GetSpreadPips();
   
   BuildAsiaRange();
   r.c1_range_valid = g_asia_box.is_valid;
   
   DetectSweep();
   r.c2_sweep = g_sweep_event.detected;
   r.sweep_level = g_sweep_event.price;
   
   if(g_sweep_event.detected)
   {
      r.c3_vol_exhaust = CheckVolExhaustion(g_sweep_event.bar_idx);
      r.c4_rejection = DetectRejection(g_sweep_event.direction);
      r.c5_rsi_extreme = CheckRSIExtreme(g_sweep_event.direction, g_sweep_event.bar_idx);
   }
   else
   {
      r.c3_vol_exhaust = false;
      r.c4_rejection = CheckRejectionTF(InpE2_TF, DIRECTION_BUY, InpE2_RejectionBars) ||
                       CheckRejectionTF(InpE2_TF, DIRECTION_SELL, InpE2_RejectionBars);
      r.c5_rsi_extreme = false;
   }
   
   r.confidence = 0;
   if(r.c1_range_valid) r.confidence += 15;
   if(r.c2_sweep) r.confidence += 25;
   if(r.c3_vol_exhaust) r.confidence += 20;
   if(r.c4_rejection) r.confidence += 20;
   if(r.c5_rsi_extreme) r.confidence += 20;
   
   if(r.spread_pips > InpMaxSpreadPips) { r.block_reason = FILTER_SPREAD; return r; }
   if(!r.c1_range_valid) { r.block_reason = FILTER_NO_RANGE; return r; }
   if(!r.c2_sweep) { r.block_reason = FILTER_NO_SWEEP; return r; }
   r.direction = g_sweep_event.direction;
   
   if(!r.c3_vol_exhaust) { r.block_reason = FILTER_VOLUME; r.direction = DIRECTION_NONE; return r; }
   if(!r.c4_rejection) { r.block_reason = FILTER_NO_REJECTION; r.direction = DIRECTION_NONE; return r; }
   if(!r.c5_rsi_extreme) { r.block_reason = FILTER_RSI; r.direction = DIRECTION_NONE; return r; }
   
   double ask = SymbolInfoDouble(InpSymbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(InpSymbol, SYMBOL_BID);
   double entry = g_sweep_event.direction == DIRECTION_BUY ? ask : bid;
   
   double pip = GetPipSize();
   double sl_buf = InpE2_SweepMinPips * pip * 3;
   
   r.entry_price = entry;
   r.sl_price = g_sweep_event.direction == DIRECTION_BUY ? g_asia_box.lo - sl_buf : g_asia_box.hi + sl_buf;
   r.tp_price = ComputeTP(g_sweep_event.direction, entry);
   r.vwap = g_vp.poc;
   
   double risk = MathAbs(entry - r.sl_price);
   double reward = MathAbs(r.tp_price - entry);
   if(reward < risk * 0.9) { r.block_reason = FILTER_LOW_RR; r.direction = DIRECTION_NONE; return r; }
   
   r.fired = true;
   return r;
}

//+------------------------------------------------------------------+
//| POSITION MANAGEMENT                                              |
//+------------------------------------------------------------------+
bool IsPartialDone(int ticket)
{
   for(int i = 0; i < ArraySize(g_partial_info); i++)
   {
      if(g_partial_info[i].ticket == ticket)
         return g_partial_info[i].done;
   }
   return false;
}

void MarkPartialDone(int ticket)
{
   for(int i = 0; i < ArraySize(g_partial_info); i++)
   {
      if(g_partial_info[i].ticket == ticket)
      {
         g_partial_info[i].done = true;
         g_partial_info[i].time = TimeCurrent();
         return;
      }
   }
   
   int idx = ArraySize(g_partial_info);
   ArrayResize(g_partial_info, idx + 1);
   g_partial_info[idx].ticket = ticket;
   g_partial_info[idx].done = true;
   g_partial_info[idx].time = TimeCurrent();
}

void ManagePositions(ENUM_ENGINE_STATE engine)
{
   if(!PositionSelect(InpSymbol)) return;
   
   uint total = PositionsTotal();
   for(uint i = 0; i < total; i++)
   {
      if(!PositionGetSymbol(i)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagic) continue;
      if(PositionGetString(POSITION_SYMBOL) != InpSymbol) continue;
      
      double entry = PositionGetDouble(POSITION_PRICE_OPEN);
      double cur = PositionGetDouble(POSITION_PRICE_CURRENT);
      double sl = PositionGetDouble(POSITION_SL);
      double tp = PositionGetDouble(POSITION_TP);
      double vol = PositionGetDouble(POSITION_VOLUME);
      int type = (int)PositionGetInteger(POSITION_TYPE);
      int ticket = (int)PositionGetInteger(POSITION_TICKET);
      bool is_buy = type == POSITION_TYPE_BUY;
      int digits = (int)SymbolInfoInteger(InpSymbol, SYMBOL_DIGITS);
      
      double pip = GetPipSize();
      double pt = GetPoint();
      double profit_pips = MathAbs(cur - entry) / pip;
      
      if(engine == ENGINE_KILLZONE_SMC)
      {
         double risk_pts = MathAbs(entry - sl) / pt;
         if(risk_pts <= 0) risk_pts = InpBE_TriggerPtsE1 * 2;
         double be_trigger_pts = risk_pts * 1.5;
         
         if(profit_pips >= be_trigger_pts / 10.0 && !IsPartialDone(ticket))
         {
            double close_vol = vol * InpPartialClosePct / 100.0;
            
            if(close_vol >= SymbolInfoDouble(InpSymbol, SYMBOL_VOLUME_MIN))
            {
               if(g_trade.SellPartial(close_vol, ticket))
               {
                  MarkPartialDone(ticket);
                  double be_buf = InpBE_BufferPipsE1 * pip;
                  double new_sl = is_buy ? entry + be_buf : entry - be_buf;
                  new_sl = NormalizeDouble(new_sl, digits);
                  if(is_buy && new_sl > sl) g_trade.PositionModify(ticket, new_sl, tp);
                  else if(!is_buy && (sl == 0 || new_sl < sl)) g_trade.PositionModify(ticket, new_sl, tp);
               }
            }
         }
         
         if(IsPartialDone(ticket))
         {
            double atr = GetCachedATR();
            double trail_mult = InpTrailATR_Mult;
            double step = InpTrailStepPoints * pt;
            
            if(is_buy)
            {
               double new_sl = cur - atr * trail_mult;
               new_sl = NormalizeDouble(new_sl, digits);
               if(new_sl > sl + step && new_sl < cur)
               {
                  double min_sl = cur - atr * 0.5;
                  new_sl = MathMax(new_sl, min_sl);
                  g_trade.PositionModify(ticket, new_sl, tp);
               }
            }
            else
            {
               double new_sl = cur + atr * trail_mult;
               new_sl = NormalizeDouble(new_sl, digits);
               if((sl == 0 || new_sl < sl - step) && new_sl > cur)
               {
                  double min_sl = cur + atr * 0.5;
                  new_sl = MathMin(new_sl, min_sl);
                  g_trade.PositionModify(ticket, new_sl, tp);
               }
            }
         }
      }
      else
      {
         if(profit_pips >= InpBE_TriggerE2 && !IsPartialDone(ticket))
         {
            double be_buf = InpBE_BufferPips * pip;
            double new_sl = is_buy ? entry + be_buf : entry - be_buf;
            new_sl = NormalizeDouble(new_sl, digits);
            bool ok = (is_buy && (new_sl > sl || sl == 0)) || (!is_buy && (new_sl < sl || sl == 0));
            if(ok && g_trade.PositionModify(ticket, new_sl, tp))
               MarkPartialDone(ticket);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| NEURAL FEEDBACK SYSTEM                                           |
//+------------------------------------------------------------------+
void RecordTrade(ENUM_ENGINE_STATE engine, bool is_win, double profit, double confidence)
{
   EngineStats &stats = (engine == ENGINE_KILLZONE_SMC) ? g_e1_stats : g_e2_stats;
   
   stats.total_trades++;
   stats.today_trades++;
   stats.today_pnl += profit;
   if(is_win) stats.wins++;
   if(stats.total_trades > 0)
      stats.accuracy = (double)stats.wins / stats.total_trades * 100;
   
   if(is_win)
   {
      stats.win_streak++;
      stats.loss_streak = 0;
   }
   else
   {
      stats.loss_streak++;
      stats.win_streak = 0;
   }
   
   if(stats.total_trades >= InpNF_TradeMemory)
   {
      if(stats.accuracy < InpNF_MinAccuracy && !stats.is_paused)
      {
         stats.is_paused = true;
         stats.paused_until = TimeCurrent() + InpNF_PauseMins * 60;
      }
      else if(stats.accuracy >= 85.0)
      {
         stats.is_paused = false;
      }
   }
   
   if(stats.is_paused && TimeCurrent() >= stats.paused_until)
      stats.is_paused = false;
}

bool IsEnginePaused(ENUM_ENGINE_STATE engine)
{
   EngineStats &stats = (engine == ENGINE_KILLZONE_SMC) ? g_e1_stats : g_e2_stats;
   if(stats.is_paused && TimeCurrent() >= stats.paused_until)
   {
      stats.is_paused = false;
      return false;
   }
   return stats.is_paused;
}

//+------------------------------------------------------------------+
//| TRADE EXECUTION                                                   |
//+------------------------------------------------------------------+
double CalculateLotE1(double sl_pips)
{
   double lot = InpFixedLot;
   
   if(sl_pips <= 0) return lot;
   
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   if(balance <= 0) return lot;
   
   double risk_amount = balance * InpRiskPct / 100.0;
   double tick_value = SymbolInfoDouble(InpSymbol, SYMBOL_TRADE_TICK_VALUE);
   double tick_size = SymbolInfoDouble(InpSymbol, SYMBOL_TRADE_TICK_SIZE);
   double pip = GetPipSize();
   
   if(tick_size <= 0 || tick_value <= 0 || pip <= 0) return lot;
   
   lot = risk_amount / (sl_pips * pip / tick_size * tick_value);
   
   if(!MathIsValidNumber(lot) || lot <= 0) return lot;
   
   double vol_min = SymbolInfoDouble(InpSymbol, SYMBOL_VOLUME_MIN);
   double vol_max = SymbolInfoDouble(InpSymbol, SYMBOL_VOLUME_MAX);
   double vol_step = SymbolInfoDouble(InpSymbol, SYMBOL_VOLUME_STEP);
   
   lot = MathMax(vol_min, MathMin(vol_max, MathFloor(lot / vol_step) * vol_step));
   
   return MathIsValidNumber(lot) ? lot : vol_min;
}

bool OpenTrade(string symbol, ENUM_TRADE_DIRECTION direction, double lot, double sl, double tp, string comment)
{
   double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
   double price = direction == DIRECTION_BUY ? ask : bid;
   
   ENUM_ORDER_TYPE type = direction == DIRECTION_BUY ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   
   if(direction == DIRECTION_BUY && (sl >= price || tp <= price)) return false;
   if(direction == DIRECTION_SELL && (sl <= price || tp >= price)) return false;
   
   return g_trade.PositionOpen(symbol, type, lot, price, sl, tp, comment);
}

//+------------------------------------------------------------------+
//| ENGINE STATE DETERMINATION                                        |
//+------------------------------------------------------------------+
ENUM_ENGINE_STATE GetEngineState()
{
   int utc_h = GetUTC_Hour();
   
   if(utc_h >= InpDeadZoneStart || utc_h < 0) return ENGINE_DEAD_ZONE;
   
   string kz_type;
   if(IsInKillZone(kz_type)) return ENGINE_KILLZONE_SMC;
   
   return ENGINE_OFFZONE_REVERSION;
}

//+------------------------------------------------------------------+
//| CHECK CLOSED TRADES                                               |
//+------------------------------------------------------------------+
datetime g_last_deal_check = 0;

void CheckClosedTrades()
{
   if(TimeCurrent() - g_last_deal_check < 60) return;
   g_last_deal_check = TimeCurrent();
   
   datetime from_time = TimeCurrent() - 7200;
   
   HistorySelect(from_time, TimeCurrent());
   uint total = HistoryDealsTotal();
   
   for(uint i = 0; i < total; i++)
   {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket == 0) continue;
      
      ulong magic = HistoryDealGetInteger(ticket, DEAL_MAGIC);
      if(magic != InpMagic) continue;
      
      long entry_type = HistoryDealGetInteger(ticket, DEAL_ENTRY);
      if(entry_type != DEAL_ENTRY_OUT) continue;
      
      string comment = HistoryDealGetString(ticket, DEAL_COMMENT);
      double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT);
      
      ENUM_ENGINE_STATE engine = ENGINE_KILLZONE_SMC;
      if(StringFind(comment, "IAE_v5_E2") >= 0) engine = ENGINE_OFFZONE_REVERSION;
      else if(StringFind(comment, "IAE_v5_E1") < 0) continue;
      
      RecordTrade(engine, profit > 0, profit, 0);
   }
   
   HistorySelect(0, TimeCurrent());
}

//+------------------------------------------------------------------+
//| MAIN EA ONTICK                                                    |
//+------------------------------------------------------------------+
void OnTick()
{
   datetime cur_bar = GetBarTime(InpEntry_TF, 0);
   if(cur_bar != g_last_bar_time)
   {
      g_last_bar_time = cur_bar;
      
      g_current_engine = GetEngineState();
      
      if(g_current_engine == ENGINE_KILLZONE_SMC)
      {
         SMCResult smc = EvaluateEngine1();
         g_smc_result = smc;
         
         if(smc.fired && !IsEnginePaused(ENGINE_KILLZONE_SMC))
         {
            bool has_pos = false;
            uint total = PositionsTotal();
            for(uint i = 0; i < total; i++)
            {
               if(!PositionGetSymbol(i)) continue;
               if(PositionGetInteger(POSITION_MAGIC) == InpMagic && 
                  PositionGetString(POSITION_SYMBOL) == InpSymbol)
               { has_pos = true; break; }
            }
            
            if(!has_pos)
            {
               double atr = GetCachedATR();
               double sl_pips = atr * InpATR_SL_Mult / GetPipSize();
               double lot = CalculateLotE1(sl_pips);
               string comment = "IAE_v5_E1";
               
               OpenTrade(InpSymbol, smc.direction, lot, smc.sl_price, smc.tp1_price, comment);
            }
         }
      }
      else if(g_current_engine == ENGINE_OFFZONE_REVERSION)
      {
         RevResult rev = EvaluateEngine2();
         
         if(rev.fired && !IsEnginePaused(ENGINE_OFFZONE_REVERSION))
         {
            bool has_pos = false;
            uint total = PositionsTotal();
            for(uint i = 0; i < total; i++)
            {
               if(!PositionGetSymbol(i)) continue;
               if(PositionGetInteger(POSITION_MAGIC) == InpMagic &&
                  PositionGetString(POSITION_SYMBOL) == InpSymbol)
               { has_pos = true; break; }
            }
            
            if(!has_pos)
            {
               string comment = "IAE_v5_E2";
               OpenTrade(InpSymbol, rev.direction, InpFixedLot, rev.sl_price, rev.tp_price, comment);
            }
         }
      }
      
      CheckClosedTrades();
   }
   
   datetime now = TimeCurrent();
   if(now - g_last_pos_check >= InpPositionMgmtSec)
   {
      g_last_pos_check = now;
      ManagePositions(g_current_engine);
   }
}

//+------------------------------------------------------------------+
//| EA ONINIT                                                          |
//+------------------------------------------------------------------+
int OnInit()
{
   g_trade.SetExpertMagicNumber(InpMagic);
   g_trade.SetDeviationInPoints(InpMaxSlippage);
   g_trade.SetTypeFilling(ORDER_FILLING_FOK);
   g_trade.SetAsyncMode(false);
   
   ArrayResize(g_partial_info, 0);
   
   g_e1_stats.total_trades = 0;
   g_e1_stats.wins = 0;
   g_e1_stats.accuracy = 100;
   g_e1_stats.is_paused = false;
   g_e1_stats.today_trades = 0;
   g_e1_stats.today_pnl = 0;
   g_e1_stats.win_streak = 0;
   g_e1_stats.loss_streak = 0;
   
   g_e2_stats = g_e1_stats;
   
   if(!SymbolSelect(InpSymbol, true))
   {
      Print("Failed to select symbol: ", InpSymbol);
      return INIT_PARAMETERS_INCORRECT;
   }
   
   Print("=== INSTITUTIONAL ALPHA ENGINE v5.0 INITIALIZED ===");
   Print("Symbol: ", InpSymbol, " | Magic: ", InpMagic);
   Print("DXY: ", InpUseDXY, " | VIX: ", InpUseVIX, " | VP: ", InpUseVP);
   
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| EA ONDEINIT                                                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   Print("Alpha Engine v5.0 stopped. Reason: ", reason);
}

//+------------------------------------------------------------------+
//| EA ONCALCULATE                                                    |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
   return rates_total;
}
//+------------------------------------------------------------------+
