//+------------------------------------------------------------------+
//|                                            PrimeBotLicense.mqh   |
//|                              Copyright PrimeBot 2025             |
//|                     https://www.primebotportfolio.com.br/        |
//+------------------------------------------------------------------+
#property copyright "Copyright PrimeBot 2025"
#property link      "https://www.primebotportfolio.com.br/"
#property version   "1.00"

//+------------------------------------------------------------------+
//| Sistema de Licenciamento PrimeBot                               |
//+------------------------------------------------------------------+
class CPrimeBotLicense
{
private:
   string            m_license_account;      // Conta autorizada ("0" = universal)
   datetime          m_license_expiration;   // Data de expiração
   bool              m_is_valid;              // Status da licença
   string            m_license_message;       // Mensagem de status
   
public:
   //+------------------------------------------------------------------+
   //| Construtor                                                       |
   //+------------------------------------------------------------------+
   CPrimeBotLicense()
   {
      m_license_account = "0";
      m_license_expiration = 0;
      m_is_valid = false;
      m_license_message = "";
   }
   
   //+------------------------------------------------------------------+
   //| Configurar licença                                              |
   //+------------------------------------------------------------------+
   void SetLicense(string account, datetime expiration)
   {
      m_license_account = account;
      m_license_expiration = expiration;
   }
   
   //+------------------------------------------------------------------+
   //| Verificar licença                                               |
   //+------------------------------------------------------------------+
   bool CheckLicense()
   {
      m_is_valid = false;
      
      // Obter informações da conta atual
      long current_account = AccountInfoInteger(ACCOUNT_LOGIN);
      datetime current_time = TimeCurrent();
      
      // Verificar se é licença universal
      bool is_universal = (StringToInteger(m_license_account) == 0);
      
      // Verificar conta
      bool account_valid = is_universal || (current_account == StringToInteger(m_license_account));
      
      // Verificar data de expiração
      bool time_valid = (current_time <= m_license_expiration);
      
      // Montar mensagem de status
      if(!account_valid)
      {
         m_license_message = StringFormat("❌ LICENÇA INVÁLIDA - Conta não autorizada! | Conta atual: %d | Conta autorizada: %s",
                                         current_account, m_license_account);
         Alert("CONTA NÃO AUTORIZADA! EA Bloqueado.");
         return false;
      }
      
      if(!time_valid)
      {
         m_license_message = StringFormat("❌ LICENÇA EXPIRADA! | Data de expiração: %s | Data atual: %s",
                                         TimeToString(m_license_expiration, TIME_DATE),
                                         TimeToString(current_time, TIME_DATE));
         Alert("LICENÇA EXPIRADA! EA Bloqueado.");
         return false;
      }
      
      // Licença válida
      m_is_valid = true;
      string license_type = is_universal ? "UNIVERSAL" : "ESPECÍFICA";
      
      m_license_message = StringFormat("✅ LICENÇA %s VÁLIDA | Conta: %d | Expira em: %s",
                                      license_type,
                                      current_account,
                                      TimeToString(m_license_expiration, TIME_DATE));
      
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Exibir informações da licença no log                           |
   //+------------------------------------------------------------------+
   void PrintLicenseInfo()
   {
      Print("╔══════════════════════════════════════════════════════════════╗");
      Print("║           SISTEMA DE LICENCIAMENTO PRIMEBOT 2025            ║");
      Print("╠══════════════════════════════════════════════════════════════╣");
      
      if(m_is_valid)
      {
         Print("║ Status: ✅ LICENÇA VÁLIDA                                   ║");
         
         if(StringToInteger(m_license_account) == 0)
         {
            Print("║ Tipo: UNIVERSAL (Qualquer conta)                            ║");
         }
         else
         {
            Print("║ Tipo: ESPECÍFICA                                            ║");
            Print("║ Conta Autorizada: ", m_license_account, "                   ║");
         }
         
         Print("║ Conta Atual: ", AccountInfoInteger(ACCOUNT_LOGIN), "        ║");
         Print("║ Expira em: ", TimeToString(m_license_expiration, TIME_DATE), " ║");
         
         // Calcular dias restantes
         int days_left = (int)((m_license_expiration - TimeCurrent()) / 86400);
         if(days_left > 0)
         {
            Print("║ Dias restantes: ", days_left, "                            ║");
            
            // Avisos de expiração próxima
            if(days_left <= 7)
            {
               Print("║ ⚠️ ATENÇÃO: Licença expira em breve!                        ║");
            }
         }
      }
      else
      {
         Print("║ Status: ❌ LICENÇA INVÁLIDA                                 ║");
         Print("║ ", m_license_message, "                                     ║");
      }
      
      Print("╠══════════════════════════════════════════════════════════════╣");
      Print("║    © PrimeBot 2025 - www.primebotportfolio.com.br           ║");
      Print("╚══════════════════════════════════════════════════════════════╝");
   }
   
   //+------------------------------------------------------------------+
   //| Obter dias restantes da licença                                 |
   //+------------------------------------------------------------------+
   int GetDaysLeft()
   {
      if(!m_is_valid) return 0;
      
      int days = (int)((m_license_expiration - TimeCurrent()) / 86400);
      return (days > 0) ? days : 0;
   }
   
   //+------------------------------------------------------------------+
   //| Verificar se está próximo da expiração                          |
   //+------------------------------------------------------------------+
   bool IsExpiringSoon(int warning_days = 7)
   {
      int days_left = GetDaysLeft();
      return (days_left > 0 && days_left <= warning_days);
   }
   
   //+------------------------------------------------------------------+
   //| Getters                                                         |
   //+------------------------------------------------------------------+
   bool     IsValid()           { return m_is_valid; }
   string   GetMessage()         { return m_license_message; }
   datetime GetExpirationDate()  { return m_license_expiration; }
   string   GetLicenseAccount()  { return m_license_account; }
};
