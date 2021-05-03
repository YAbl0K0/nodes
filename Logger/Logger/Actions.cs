namespace OOP
{
    public static class Actions
    {
        public static Result Information()
        {
            Logger.Instance.Log(LogType.Information, $"Inform");
            return new Result { Status = true };
        }
        public static Result Warning()
        {
            Logger.Instance.Log(LogType.Warning, $"Warning");

            return new Result { Status = true };
        }
        public static Result Error()
        {
            Logger.Instance.Log(LogType.Error, $"Error");

            return new Result { Status = false, Massage = "Err" };
        }
    }
}


