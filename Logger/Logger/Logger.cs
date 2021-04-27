using System;
using System.Text;

namespace OOP
{

    class Logger
    {
        private static Logger _logger = null;



        private static StringBuilder _sb = new StringBuilder();
        private Logger()
        {
        }

        public static Logger Instance
        {
            get
            {
                return _logger ?? new Logger();
            }

        }

        public void Log(LogType logType, string massage)
        {
            var loggerMassage = $"Data: {DateTime.UtcNow.TimeOfDay}. {{{logType}}}. Massage : {massage}";
            _sb.AppendLine(loggerMassage);
            Console.WriteLine(loggerMassage);
        }

        public string GetAllLogs()
        {
            return _sb.ToString();

        }

    }

}