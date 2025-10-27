// Install the .NET library via NuGet: dotnet add package Azure.AI.OpenAI --prerelease
using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using Azure;
using Azure.AI.OpenAI;
using Azure.Identity;
using OpenAI.Chat;

using static System.Environment;
using System.Text.Json;

async Task RunAsync()
{
    // Retrieve the OpenAI endpoint from environment variables
    var endpoint = GetEnvironmentVariable("AZURE_OPENAI_ENDPOINT") ?? "https://datasynchro-openai.openai.azure.com/";
    if (string.IsNullOrEmpty(endpoint))
    {
        Console.WriteLine("Please set the AZURE_OPENAI_ENDPOINT environment variable.");
        return;
    }

    // Use DefaultAzureCredential for Entra ID authentication
    var credential = new DefaultAzureCredential();

    // Initialize the AzureOpenAIClient
    var azureClient = new AzureOpenAIClient(new Uri(endpoint), credential);

    // Initialize the ChatClient with the specified deployment name
    ChatClient chatClient = azureClient.GetChatClient("gpt-4o");

    // Create a list of chat messages
    var messages = new List<ChatMessage>
    {
        new SystemChatMessage(@"You are an AI assistant that helps people find information."),
    };

    // Create chat completion options
    var options = new ChatCompletionOptions
    {
        Temperature = (float)0.7,
        MaxOutputTokenCount = 6553,

        TopP = (float)0.95,
        FrequencyPenalty = (float)0,
        PresencePenalty = (float)0
    };

    try
    {
        // Create the chat completion request
        ChatCompletion completion = await chatClient.CompleteChatAsync(messages, options);

        // Print the response
        if (completion != null)
        {
            Console.WriteLine(JsonSerializer.Serialize(completion, new JsonSerializerOptions() { WriteIndented = true }));
        }
        else
        {
            Console.WriteLine("No response received.");
        }
    }
    catch (Exception ex)
    {
        Console.WriteLine($"An error occurred: {ex.Message}");
    }
}

await RunAsync();