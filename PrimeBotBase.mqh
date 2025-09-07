//+------------------------------------------------------------------+
//|                                                PrimeBotBase.mqh  |
//|                              Copyright PrimeBot 2025             |
//|                     https://www.primebotportfolio.com.br/        |
//+------------------------------------------------------------------+
#property copyright "Copyright PrimeBot 2025"
#property link      "https://www.primebotportfolio.com.br/"
#property version   "1.00"

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\AccountInfo.mqh>
#include <Trade\SymbolInfo.mqh>
#include <Trade\DealInfo.mqh>

//+------------------------------------------------------------------+
//| Classe Base Principal do Sistema PrimeBot                       |
//+------------------------------------------------------------------+
class CPrimeBotBase
{
protected:
   CTrade            m_trade;
   CPositionInfo     m_position;
   CAccountInfo      m_account;
   CSymbolInfo       m_symbol;
   CDealInfo         m_deal;
   
   // Configurações básicas
   int               m_magic_number;
   string            m_symbol_name;
   ENUM_TIMEFRAMES   m_timeframe;
   
   // Estatísticas
   struct Statistics
   {
      int            total_trades;
      int            wins;
      int            losses;
      double         total_profit;
      double         total_loss;
      double         max_drawdown;
      double         current_drawdown;
      double         win_rate;
      double         profit_factor;
      datetime       last_trade_time;
      
      // Estatísticas diárias
      int            daily_trades;
      double         daily_profit;
      double         daily_loss;
      datetime       day_start;
      
      // Estatísticas mensais
      int            monthly_trades;
      double         monthly_profit;
      double         monthly_loss;
      datetime       month_start;
   };
   Statistics        m_stats;
   
   // Estado do EA
   bool              m_is_initialized;
   bool              m_is_trading_allowed;
   string            m_last_error;
   
public:
   //+------------------------------------------------------------------+
   //| Construtor                                                       |
   //+------------------------------------------------------------------+
   CPrimeBotBase()
   {
      m_is_initialized = false;
      m_is_trading_allowed = false;
      m_magic_number = 0;
      m_symbol_name = "";
      m_timeframe = PERIOD_CURRENT;
      ResetStatistics();
   }
   
   //+------------------------------------------------------------------+
   //| Destrutor                                                        |
   //+------------------------------------------------------------------+
   ~CPrimeBotBase()
   {
      Deinit();
   }
   
   //+------------------------------------------------------------------+
   //| Inicialização do sistema base                                   |
   //+------------------------------------------------------------------+
   bool Init(string symbol, ENUM_TIMEFRAMES timeframe, int magic)
   {
      m_symbol_name = symbol;
      m_timeframe = timeframe;
      m_magic_number = magic;
      
      // Configurar símbolo
      if(!m_symbol.Name(symbol))
      {
         m_last_error = "Erro ao configurar símbolo: " + symbol;
         return false;
      }
      
      // Configurar trade
      m_trade.SetExpertMagicNumber(magic);
      m_trade.SetMarginMode();
      m_trade.SetTypeFillingBySymbol(symbol);
      m_trade.SetDeviationInPoints(10);
      
      // Verificar se trading está permitido
      if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED))
      {
         m_last_error = "Trading não permitido no terminal";
         return false;
      }
      
      if(!AccountInfoInteger(ACCOUNT_TRADE_EXPERT))
      {
         m_last_error = "Trading automático não permitido na conta";
         return false;
      }
      
      if(!AccountInfoInteger(ACCOUNT_TRADE_ALLOWED))
      {
         m_last_error = "Trading não permitido para esta conta";
         return false;
      }
      
      m_is_initialized = true;
      m_is_trading_allowed = true;
      
      Print("✅ PrimeBotBase inicializado com sucesso");
      Print("   Símbolo: ", symbol);
      Print("   Timeframe: ", EnumToString(timeframe));
      Print("   Magic Number: ", magic);
      
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Desinicialização                                                |
   //+------------------------------------------------------------------+
   void Deinit()
   {
      if(m_is_initialized)
      {
         CloseAllPositions();
         DeleteAllPendingOrders();
         m_is_initialized = false;
      }
   }
   
   //+------------------------------------------------------------------+
   //| Resetar estatísticas                                            |
   //+------------------------------------------------------------------+
   void ResetStatistics()
   {
      ZeroMemory(m_stats);
      m_stats.day_start = StringToTime(TimeToString(TimeCurrent(), TIME_DATE));
      m_stats.month_start = StringToTime(StringFormat("%04d.%02d.01", 
                                        TimeYear(TimeCurrent()), 
                                        TimeMonth(TimeCurrent())));
   }
   
   //+------------------------------------------------------------------+
   //| Atualizar estatísticas                                          |
   //+------------------------------------------------------------------+
   void UpdateStatistics()
   {
      // Verificar novo dia
      datetime current_day = StringToTime(TimeToString(TimeCurrent(), TIME_DATE));
      if(current_day != m_stats.day_start)
      {
         m_stats.day_start = current_day;
         m_stats.daily_trades = 0;
         m_stats.daily_profit = 0;
         m_stats.daily_loss = 0;
      }
      
      // Verificar novo mês
      datetime current_month = StringToTime(StringFormat("%04d.%02d.01", 
                                           TimeYear(TimeCurrent()), 
                                           TimeMonth(TimeCurrent())));
      if(current_month != m_stats.month_start)
      {
         m_stats.month_start = current_month;
         m_stats.monthly_trades = 0;
         m_stats.monthly_profit = 0;
         m_stats.monthly_loss = 0;
      }
      
      // Calcular estatísticas do histórico
      CalculateHistoryStats();
      
      // Calcular métricas derivadas
      if(m_stats.wins + m_stats.losses > 0)
      {
         m_stats.win_rate = (double)m_stats.wins / (m_stats.wins + m_stats.losses) * 100;
      }
      
      if(m_stats.total_loss != 0)
      {
         m_stats.profit_factor = MathAbs(m_stats.total_profit / m_stats.total_loss);
      }
   }
   
   //+------------------------------------------------------------------+
   //| Calcular estatísticas do histórico                              |
   //+------------------------------------------------------------------+
   void CalculateHistoryStats()
   {
      datetime today = StringToTime(TimeToString(TimeCurrent(), TIME_DATE));
      datetime month_start = StringToTime(StringFormat("%04d.%02d.01", 
                                         TimeYear(TimeCurrent()), 
                                         TimeMonth(TimeCurrent())));
      
      // Selecionar histórico completo
      if(!HistorySelect(0, TimeCurrent()))
         return;
         
      int deals = HistoryDealsTotal();
      
      // Resetar contadores totais
      m_stats.total_trades = 0;
      m_stats.wins = 0;
      m_stats.losses = 0;
      m_stats.total_profit = 0;
      m_stats.total_loss = 0;
      
      for(int i = 0; i < deals; i++)
      {
         ulong ticket = HistoryDealGetTicket(i);
         if(ticket == 0) continue;
         
         // Verificar magic number e símbolo
         if(HistoryDealGetInteger(ticket, DEAL_MAGIC) != m_magic_number) continue;
         if(HistoryDealGetString(ticket, DEAL_SYMBOL) != m_symbol_name) continue;
         
         // Pular deals de entrada
         ENUM_DEAL_ENTRY entry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(ticket, DEAL_ENTRY);
         if(entry == DEAL_ENTRY_IN) continue;
         
         double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT);
         double commission = HistoryDealGetDouble(ticket, DEAL_COMMISSION);
         double swap = HistoryDealGetDouble(ticket, DEAL_SWAP);
         double total = profit + commission + swap;
         
         datetime deal_time = (datetime)HistoryDealGetInteger(ticket, DEAL_TIME);
         
         // Estatísticas totais
         m_stats.total_trades++;
         if(total > 0)
         {
            m_stats.wins++;
            m_stats.total_profit += total;
         }
         else if(total < 0)
         {
            m_stats.losses++;
            m_stats.total_loss += total;
         }
         
         // Estatísticas diárias
         if(deal_time >= today)
         {
            m_stats.daily_trades++;
            if(total > 0)
               m_stats.daily_profit += total;
            else
               m_stats.daily_loss += total;
         }
         
         // Estatísticas mensais
         if(deal_time >= month_start)
         {
            m_stats.monthly_trades++;
            if(total > 0)
               m_stats.monthly_profit += total;
            else
               m_stats.monthly_loss += total;
         }
      }
   }
   
   //+------------------------------------------------------------------+
   //| Contar posições abertas                                         |
   //+------------------------------------------------------------------+
   int CountPositions(ENUM_POSITION_TYPE type = -1)
   {
      int count = 0;
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         if(m_position.SelectByIndex(i))
         {
            if(m_position.Magic() != m_magic_number) continue;
            if(m_position.Symbol() != m_symbol_name) continue;
            
            if(type == -1 || m_position.PositionType() == type)
               count++;
         }
      }
      return count;
   }
   
   //+------------------------------------------------------------------+
   //| Calcular lucro total das posições abertas                       |
   //+------------------------------------------------------------------+
   double GetOpenProfit()
   {
      double profit = 0;
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         if(m_position.SelectByIndex(i))
         {
            if(m_position.Magic() != m_magic_number) continue;
            if(m_position.Symbol() != m_symbol_name) continue;
            
            profit += m_position.Profit() + m_position.Commission() + m_position.Swap();
         }
      }
      return profit;
   }
   
   //+------------------------------------------------------------------+
   //| Fechar todas as posições                                        |
   //+------------------------------------------------------------------+
   bool CloseAllPositions()
   {
      bool result = true;
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         if(m_position.SelectByIndex(i))
         {
            if(m_position.Magic() != m_magic_number) continue;
            if(m_position.Symbol() != m_symbol_name) continue;
            
            if(!m_trade.PositionClose(m_position.Ticket()))
            {
               m_last_error = "Erro ao fechar posição: " + IntegerToString(GetLastError());
               result = false;
            }
         }
      }
      return result;
   }
   
   //+------------------------------------------------------------------+
   //| Deletar todas as ordens pendentes                               |
   //+------------------------------------------------------------------+
   bool DeleteAllPendingOrders()
   {
      bool result = true;
      for(int i = OrdersTotal() - 1; i >= 0; i--)
      {
         ulong ticket = OrderGetTicket(i);
         if(ticket == 0) continue;
         
         if(OrderGetInteger(ORDER_MAGIC) != m_magic_number) continue;
         if(OrderGetString(ORDER_SYMBOL) != m_symbol_name) continue;
         
         if(!m_trade.OrderDelete(ticket))
         {
            m_last_error = "Erro ao deletar ordem: " + IntegerToString(GetLastError());
            result = false;
         }
      }
      return result;
   }
   
   //+------------------------------------------------------------------+
   //| Verificar se é nova barra                                       |
   //+------------------------------------------------------------------+
   bool IsNewBar()
   {
      static datetime last_time = 0;
      datetime current_time = iTime(m_symbol_name, m_timeframe, 0);
      
      if(current_time != last_time)
      {
         last_time = current_time;
         return true;
      }
      return false;
   }
   
   //+------------------------------------------------------------------+
   //| Normalizar lote                                                 |
   //+------------------------------------------------------------------+
   double NormalizeLot(double lot)
   {
      double min_lot = m_symbol.LotsMin();
      double max_lot = m_symbol.LotsMax();
      double lot_step = m_symbol.LotsStep();
      
      if(lot < min_lot) lot = min_lot;
      if(lot > max_lot) lot = max_lot;
      
      return NormalizeDouble(MathFloor(lot / lot_step) * lot_step, 2);
   }
   
   //+------------------------------------------------------------------+
   //| Calcular tamanho do lote baseado em risco                       |
   //+------------------------------------------------------------------+
   double CalculateLotByRisk(double risk_percent, double stop_loss_points)
   {
      if(stop_loss_points <= 0) return m_symbol.LotsMin();
      
      double account_balance = m_account.Balance();
      double risk_money = account_balance * risk_percent / 100.0;
      double tick_value = m_symbol.TickValue();
      double tick_size = m_symbol.TickSize();
      double point_value = tick_value * (m_symbol.Point() / tick_size);
      
      double lot = risk_money / (stop_loss_points * point_value);
      
      return NormalizeLot(lot);
   }
   
   //+------------------------------------------------------------------+
   //| Getters para estatísticas                                       |
   //+------------------------------------------------------------------+
   int    GetTotalTrades()     { return m_stats.total_trades; }
   int    GetWins()            { return m_stats.wins; }
   int    GetLosses()          { return m_stats.losses; }
   double GetTotalProfit()     { return m_stats.total_profit; }
   double GetTotalLoss()       { return m_stats.total_loss; }
   double GetWinRate()         { return m_stats.win_rate; }
   double GetProfitFactor()    { return m_stats.profit_factor; }
   int    GetDailyTrades()     { return m_stats.daily_trades; }
   double GetDailyProfit()     { return m_stats.daily_profit; }
   double GetDailyLoss()       { return m_stats.daily_loss; }
   int    GetMonthlyTrades()   { return m_stats.monthly_trades; }
   double GetMonthlyProfit()   { return m_stats.monthly_profit; }
   double GetMonthlyLoss()     { return m_stats.monthly_loss; }
   
   //+------------------------------------------------------------------+
   //| Verificar se trading está permitido                             |
   //+------------------------------------------------------------------+
   bool IsTradingAllowed()     { return m_is_trading_allowed; }
   string GetLastError()        { return m_last_error; }
   
   //+------------------------------------------------------------------+
   //| Verificar horário de trading                                    |
   //+------------------------------------------------------------------+
   bool IsTimeToTrade(int start_hour, int start_minute, int end_hour, int end_minute)
   {
      MqlDateTime current_time;
      TimeToStruct(TimeCurrent(), current_time);
      
      int current_minutes = current_time.hour * 60 + current_time.min;
      int start_minutes = start_hour * 60 + start_minute;
      int end_minutes = end_hour * 60 + end_minute;
      
      if(start_minutes <= end_minutes)
      {
         return (current_minutes >= start_minutes && current_minutes <= end_minutes);
      }
      else
      {
         return (current_minutes >= start_minutes || current_minutes <= end_minutes);
      }
   }
};
