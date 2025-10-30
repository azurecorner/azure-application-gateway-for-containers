using Microsoft.AspNetCore.Mvc;

namespace ChatBot.Controllers
{
    [ApiController]
    [Route("[controller]")]
    public class ChatController : ControllerBase
    {
        private readonly ChatbotService _service;

        public ChatController(ChatbotService service) => _service = service;

        [HttpPost]
        public async Task<IActionResult> Post([FromBody] ChatRequest req)
        {
            var reply = await _service.GetReplyAsync(req.UserId, req.Message, HttpContext.RequestAborted);
            return Ok(new { reply });
        }
    }
}