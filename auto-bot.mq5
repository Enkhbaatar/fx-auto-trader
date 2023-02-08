//+------------------------------------------------------------------+
//|                                               price_provider.mq5 |
//|                                  Copyright 2022, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2022, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+

string address = "localhost";
int    port = 8888;
int socket;

MqlRates candles[];
short num_msg = 0;
bool closed = false;
int candle_size = 1440;
bool notifiedClosedCandle = false;
double RISK = 0.01;

struct PendingOrder {
   string direction;
   double entry;
   double sl;
   double tp;
   double sl_pips;
   double tp_pips;
};

PendingOrder order;
bool orderFound = false;

int OnInit()
  {
   Print("[INFO]\tInitiated indicator.");
   return(INIT_SUCCEEDED);
  }
  
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//--- 
   if (reason!=REASON_CHARTCHANGE)
        SocketClose(socket);
   ObjectsDeleteAll(ChartID(),-1,-1);
  }
  
  
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
      datetime tm=TimeCurrent();
      string str1="Date and time with minutes: "+TimeToString(tm);
      string time_min_sec="" + TimeToString(tm,TIME_SECONDS);
      string sep=":";
      ushort u_sep;
      string result[];
      u_sep=StringGetCharacter(sep,0);
      int k=StringSplit(time_min_sec,u_sep,result);
      
      if(result[k-1] == "00") {
         if(notifiedClosedCandle == false) {
            notifiedClosedCandle = true;
            identifyCandle();
            sentRequest();
         }
      } else {
         if(notifiedClosedCandle == true) {
            notifiedClosedCandle = false;
         }
      }
      //Print(str5);
  }
  
int profitX = 1;
  
void identifyCandle() 
{
   MqlRates new_candles[];
   string msg;
  
   CopyRates(_Symbol, PERIOD_M1, 1, 1, new_candles);
   
   string symbol = _Symbol;
   double open = new_candles[0].open;
   double high = new_candles[0].high;
   double low = new_candles[0].low;
   double close = new_candles[0].close;
   string time = new_candles[0].time;
   double volume = new_candles[0].tick_volume;
   
   double body_size = 0;
   double upper_wick_size = 0;
   double lower_wick_size = 0;
   
   if (open > close) {
      body_size = open - close;
      upper_wick_size = high - open;
      lower_wick_size = close - low;
   } else {
      body_size = close - open;
      upper_wick_size = high - close;
      lower_wick_size = open - low;
   }
  
   
   Print("HOUW: ", upper_wick_size, " HOLW: ", lower_wick_size, " Body size: ", body_size);
   
   long spread = SymbolInfoInteger(_Symbol,SYMBOL_SPREAD);
   double _spread = spread / 100;
   
   
   if(upper_wick_size >= body_size && body_size >= lower_wick_size) { // && open > close
      double half_of_up_wick = upper_wick_size / 2;
      double entry_price = NormalizeDouble(((open + close) / 2), 2); //NormalizeDouble(high - _spread - half_of_up_wick, 2);
      
      double sl = NormalizeDouble((high + _spread * 1.5), 2);
      
      int sl_pips = MathRound((sl - entry_price) * 100);
      
      if(sl_pips < 30) {
         sl = NormalizeDouble((high + _spread * 2), 2);
         sl_pips = MathRound((sl - entry_price) * 100);
      }
      
      double tp = NormalizeDouble((entry_price - ((sl - entry_price) * profitX) - _spread), 2);
      int tp_pips = MathRound((entry_price - tp) * 100);
      
      order.direction = "sell";
      order.entry = entry_price;
      order.sl = sl;
      order.tp = tp;
      order.tp_pips = tp_pips;
      order.sl_pips = sl_pips;
      orderFound = true;
      StringConcatenate(msg, "Candle Time: ", time, " Direction: Sell"," Entry: ", entry_price, " SL: ", sl, " TP: ", tp , " SL Pips: ", sl_pips, " TP Pips: ", tp_pips);
      Print(msg);
   } else if(lower_wick_size >= body_size && body_size >= upper_wick_size) { // && close > open
   
      double half_of_low_wick = lower_wick_size / 2;
      double entry_price = NormalizeDouble(((open + close) / 2), 2); // NormalizeDouble(low + _spread + half_of_low_wick, 2);
      
      double sl = NormalizeDouble((low - _spread * 1.5), 2);
      int sl_pips = MathRound((entry_price - sl) * 100);
      
      if(sl_pips < 30) {
         sl = NormalizeDouble((low - _spread * 2), 2);
         sl_pips = MathRound((entry_price - sl) * 100);
      }
      
      double tp = NormalizeDouble((entry_price + ((entry_price - sl) * profitX) + _spread), 2);
      int tp_pips = MathRound((tp - entry_price) * 100);
      
      order.direction = "buy";
      order.entry = entry_price;
      order.sl = sl;
      order.tp = tp;
      order.tp_pips = tp_pips;
      order.sl_pips = sl_pips;
      orderFound = true;
      StringConcatenate(msg, "Candle Time: ", time, " Direction: Buy"," Entry: ", entry_price, " SL: ", sl, " TP: ", tp , " SL Pips: ", sl_pips, " TP Pips: ", tp_pips);
      Print(msg);
   }
}

void sentRequest() 
{
   if(orderFound) {
      double balance = AccountInfoDouble(ACCOUNT_BALANCE);
      //Print("[INFO]\tACCOUNT_MARGIN_LEVEL = ",AccountInfoDouble(ACCOUNT_MARGIN_LEVEL));
      double pip_value = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
      int units = MathPow(10, _Digits);
      string price_msg;
      MqlTick Latest_Price;
      
      SymbolInfoTick(_Symbol, Latest_Price);
      StringConcatenate(price_msg, "[INFO]\tBid Price: ", Latest_Price.bid, " Ask Price: ", Latest_Price.ask);
      Print(price_msg);
      
      if(order.direction == "sell") {
         if(order.entry <= Latest_Price.ask) {
             Print("[INFO]\tSending sell order.");
             int sl_points = (order.sl - Latest_Price.ask) * units;
             double lots = NormalizeDouble((((balance * RISK) / sl_points) / pip_value), 2);
             send_order(Latest_Price.ask, Latest_Price.bid, lots);
             orderFound = false;
         } else if (order.tp <= Latest_Price.ask) {
             orderFound = false;
             Print("[INFO]\tMissed current sell entry looking for next entery.");
         }
      } else if (order.direction == "buy") {
         if(order.entry >= Latest_Price.bid) {
             Print("[INFO]\tSending buy order.");
             int sl_points = (Latest_Price.bid - order.sl) * units;
             double lots = NormalizeDouble((((balance * RISK) / sl_points) / pip_value), 2);
             send_order(Latest_Price.ask, Latest_Price.bid, lots);
             orderFound = false;
         } else if (order.tp >= Latest_Price.bid) {
             orderFound = false;
             Print("[INFO]\tMissed current buy entry looking for next entery.");
         }
      }
  }
}

void send_order(double ask, double bid, double lots) {
   Print("[INFO]\tPosition size: ", lots);
   MqlTradeRequest mRequest;
   MqlTradeResult mResult;
   string msg;
   
   long spread = SymbolInfoInteger(_Symbol,SYMBOL_SPREAD);
   double _spread = spread / 100;
   
   ZeroMemory(mRequest);
   ZeroMemory(mResult);
   
   mRequest.action = TRADE_ACTION_DEAL;
   mRequest.symbol = _Symbol;
   mRequest.volume = lots;
   mRequest.magic = 234000;
   
  
   
   if(order.direction == "sell") {
      mRequest.type = ORDER_TYPE_SELL;
      order.entry = ask;
      order.sl_pips = MathRound((order.sl - order.entry) * 100);
      order.tp = NormalizeDouble((order.entry - ((order.sl - order.entry) * profitX) - _spread), 2);
      order.tp_pips = MathRound((order.entry - order.tp) * 100);
   } else if (order.direction == "buy") {
      mRequest.type = ORDER_TYPE_BUY;
      order.entry = bid;
      order.sl_pips = MathRound((order.entry - order.sl) * 100);
      order.tp = NormalizeDouble((order.entry + ((order.entry - order.sl) * profitX) + _spread), 2);
      order.tp_pips = MathRound((order.tp - order.entry) * 100);
   }
   
   mRequest.price = NormalizeDouble(order.entry,_Digits);
   mRequest.sl = NormalizeDouble(order.sl,_Digits);
   mRequest.tp = NormalizeDouble(order.tp,_Digits);
   
   Print("[INFO]\tEntry: ", order.entry, " Sl: ", order.sl, " Tp: ", order.tp, " Pip loose: ", order.sl_pips, " Pip tp: ", order.tp_pips);
   StringConcatenate(msg, "Pip loose: ", order.sl_pips, " Pip tp: ", order.tp_pips);
   mRequest.comment = msg;
  
   mRequest.type_filling = ORDER_FILLING_IOC;
   mRequest.deviation=200;
   bool ticket = OrderSend(mRequest,mResult);
   Print("[INFO]\tTicket: ",ticket);
   
   if(mResult.retcode ==10009 || mResult.retcode == 10008){
      Print("[INFO]\tOrder has been placed ",mResult.order);
   } else {
      Print("[INFO]\tThe sell order could not be completed ",GetLastError());
      ResetLastError();
      return;
   }  
}
  
  
//+------------------------------------------------------------------+
//| Trade function                                                   |
//+------------------------------------------------------------------+
void OnTrade()
  {
   
  }
//+------------------------------------------------------------------+
