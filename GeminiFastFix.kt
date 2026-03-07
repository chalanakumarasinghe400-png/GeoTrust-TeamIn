import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONArray
import org.json.JSONObject
import java.io.OutputStreamWriter
import java.net.HttpURLConnection
import java.net.URL

object GeminiFastFix {
    // ⚠️ Paste your API key from Google AI Studio here
    private const val API_KEY = "YOUR_API_KEY_HERE"

    // You can use the latest model here regardless of your Android Studio version
    private const val MODEL = "gemini-3.1-pro" // or "gemini-3-flash" for faster responses

    suspend fun getAnswer(prompt: String): String = withContext(Dispatchers.IO) {
        try {
            val url = URL("https://generativelanguage.googleapis.com/v1beta/models/$MODEL:generateContent?key=$API_KEY")
            val connection = url.openConnection() as HttpURLConnection
            connection.requestMethod = "POST"
            connection.setRequestProperty("Content-Type", "application/json")
            connection.doOutput = true

            // Safely build the JSON payload
            val payload = JSONObject().apply {
                put("contents", JSONArray().put(JSONObject().apply {
                    put("parts", JSONArray().put(JSONObject().apply {
                        put("text", prompt)
                    }))
                }))
            }

            // Send the request
            OutputStreamWriter(connection.outputStream).use { it.write(payload.toString()) }

            // Read the response
            if (connection.responseCode == 200) {
                val responseStr = connection.inputStream.bufferedReader().use { it.readText() }
                val json = JSONObject(responseStr)
                return@withContext json.getJSONArray("candidates")
                    .getJSONObject(0).getJSONObject("content")
                    .getJSONArray("parts").getJSONObject(0).getString("text")
            } else {
                return@withContext "API Error: ${connection.responseCode}"
            }
        } catch (e: Exception) {
            return@withContext "App Error: ${e.message}"
        }
    }
}