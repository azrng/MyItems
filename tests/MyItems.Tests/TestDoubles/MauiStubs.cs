public class Shell
{
    private static Shell? current;

    public static Shell Current
    {
        get => current ??= new Shell();
        set => current = value;
    }

    public virtual Task<bool> DisplayAlertAsync(string title, string message, string accept, string cancel)
    {
        return Task.FromResult(true);
    }

    public virtual Task DisplayAlertAsync(string title, string message, string cancel)
    {
        return Task.CompletedTask;
    }

    public virtual Task GoToAsync(string state)
    {
        return Task.CompletedTask;
    }

    public virtual Task GoToAsync(string state, IDictionary<string, object> parameters)
    {
        return Task.CompletedTask;
    }
}

public static class MainThread
{
    public static Task InvokeOnMainThreadAsync(Func<Task> action)
    {
        return action();
    }
}

public sealed class ShareFile
{
    public ShareFile(string path)
    {
        Path = path;
    }

    public string Path { get; }
}

public sealed class ShareFileRequest
{
    public string Title { get; set; } = string.Empty;
    public ShareFile? File { get; set; }
}

public sealed class Share
{
    public static Share Default { get; } = new();

    public Task RequestAsync(ShareFileRequest request)
    {
        return Task.CompletedTask;
    }
}
