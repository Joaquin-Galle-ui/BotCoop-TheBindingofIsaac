# BotCoop-The Binding of Isaac
This mod allows you to have a second player in TBOI. It's useful for completing achievements faster or if you want to play with two players without needing a real second player. It also includes an AI that can chat with you about the game; you can use any AI (Gemini, ChatGPT, Azura, etc.).

BEFORE INSTALLING THE MOD.
For “ia_puente.py,” the Repentogon path was used. If you have this mod installed (which I recommend not just for this mod), please ignore this message. If you don’t have it installed and don’t plan to, then you must change the “file path” part on line 13 of the code. The AI uses “log.txt” to read what happens in the game, so I suggest you look inside “Documents/My Games/Binding of Isaac Repentance+”; if it’s not there, you’ll likely need to remove the “+”. If you can’t find it, then look inside the “My Games” folder for the TBOI folder; if you have more than one TBOI folder, look for the most recent “log.txt” file you have.

The AI uses prompts to speak; right now it’s using a fairly “Argentine” one. You can change it however you like within the code (lines 34, 45, and 59). I suggest always telling it to use two lines when speaking, because otherwise it might give you a very absurd monologue. “ia_puente.py” is not required to play; in fact, it's completely optional.
“mando_virtual.py” is not strictly required, BUT it is highly recommended for the mod to work without bugs, since if TBOI doesn't find a second controller, it will cause the bot's health and usable items to overlap with the player's health.

How to Switch the AI Provider (From Groq to OpenAI or Gemini)
By default, this project uses Groq for its ultra-fast inference speed. However, if you want to use OpenAI (ChatGPT) or Google Gemini, you will need to change the Python library, the API Key configuration, and the model name in your ia_puente.py file.

Here is how to do it for each provider:

Option 1: Switching to OpenAI (ChatGPT)
OpenAI uses a very similar structure to Groq. You just need to change the client setup and the model string.

1. Install the library in your terminal:
pip install openai

2. Update the top of your script:

from openai import OpenAI

# Replace with your actual OpenAI API Key
OPENAI_API_KEY = "sk-your-secret-openai-key-here"
cliente = OpenAI(api_key=OPENAI_API_KEY)

3. Update the API call inside your functions (pedir_consejo_automatico and procesar_orden_usuario): (line 33,55)

# Change the model to a fast OpenAI model, like gpt-4o-mini
        respuesta = cliente.chat.completions.create(
            messages=[{"role": "user", "content": prompt}],
            model="gpt-4o-mini", 
        )
        texto = respuesta.choices[0].message.content.strip()


Option 2: Switching to Google Gemini
Gemini uses a different official library, which makes the API call structure slightly shorter and more straightforward.

1. Install the library in your terminal:

pip install google-generativeai

2. Update the top of your script:

import google.generativeai as genai

# Replace with your actual Gemini API Key
GEMINI_API_KEY = "AIzaSy-your-secret-gemini-key-here"
genai.configure(api_key=GEMINI_API_KEY)

# Initialize the model (Flash is recommended for real-time speed)
modelo_gemini = genai.GenerativeModel('gemini-1.5-flash')


3. Update the API call inside your functions:

# Gemini's call structure is much shorter
        respuesta = modelo_gemini.generate_content(prompt)
        texto = respuesta.text.strip()
