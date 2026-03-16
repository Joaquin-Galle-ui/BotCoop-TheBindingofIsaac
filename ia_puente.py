import os
import time
import json
import threading
import keyboard
from groq import Groq
import pyttsx3
import speech_recognition as sr

# --- 1. CONFIGURACIÓN ---
GROQ_API_KEY = "APY_KEY_HERE"
cliente = Groq(api_key=GROQ_API_KEY)
ruta_archivo = r"E:\SteamLibrary\steamapps\common\The Binding of Isaac Rebirth\Repentogon\Documents\My Games\Binding of Isaac Repentance+\log.txt"

# --- 2. MEMORIA GLOBAL ---
ultima_vida = -1
ultimo_item = "Ninguno"
item_actual = "Ninguno" # <-- NUEVA VARIABLE: El bot lee esto en tiempo real

# --- 3. MOTOR DE VOZ ---
def hablar_bot(texto):
    def reproducir():
        try:
            motor = pyttsx3.init()
            motor.setProperty('rate', 170)
            motor.say(texto)
            motor.runAndWait()
        except Exception as e:
            print(f"Error de voz: {e}")
    threading.Thread(target=reproducir, daemon=True).start()

# --- 4. FUNCIONES DE LA IA ---

def pedir_consejo_automatico(vida, sala, item):
    prompt = f"El usuario está jugando Isaac. Vida: {vida} medios corazones. Ítem visto: '{item}'. Reacciona a esto en MÁXIMO 20 PALABRAS. Hablá como una chica gamer del conurbano bonaerense. CORTITO Y AL PIE, una sola frase rápida. (Ejemplo: 'Uf, qué buen ítem ese, agarrémoslo' o 'Cuidado que nos matan, loco'). Traducí códigos raros como #NAME al español simple."
    try:
        respuesta = cliente.chat.completions.create(
            messages=[{"role": "user", "content": prompt}],
            model="llama-3.1-8b-instant",
        )
        return respuesta.choices[0].message.content.strip()
    except Exception as e:
        return f"(Fallo de red: {e})"

def procesar_orden_usuario(orden):
    global item_actual
    
    prompt = f"""
    Eres el compañero bot del usuario en The Binding of Isaac.
    Él te ordenó por voz: "{orden}"
    
    REGLAS ESTRICTAS:
    1. DEBES incluir UNA de estas palabras en mayúsculas: AGARRAR, BOMBA, ACTIVAR, CARTA.
    2. Tu respuesta debe tener MÁXIMO 20 PALABRAS. 
    3. Hablá con lunfardo de barrio, como una mujer, cortito y al pie. Nada de discursos ni explicaciones.
    Ejemplo válido: "De una perri, ahí te pongo la BOMBA."
    """
    try:
        respuesta = cliente.chat.completions.create(
            messages=[{"role": "user", "content": prompt}],
            model="llama-3.1-8b-instant",
        )
        texto = respuesta.choices[0].message.content.strip()
        print(f"\n🧠 BOT: {texto}")
        hablar_bot(texto)
        
        texto_upper = texto.upper()
        
        if "AGARRAR" in texto_upper:
            print("⚙️ SISTEMA: Manteniendo 'J'...")
            keyboard.press('j')
            tiempo_inicio = time.time()
            while item_actual != "Ninguno" and (time.time() - tiempo_inicio) < 4:
                time.sleep(0.05)
            keyboard.release('j')
            print("⚙️ SISTEMA: 'J' liberada.")
            
        elif "BOMBA" in texto_upper:
            print("⚙️ SISTEMA: Presionando 'F5' (Bomba del Bot)")
            keyboard.send('f5')
            
        elif "ACTIVAR" in texto_upper:
            print("⚙️ SISTEMA: Presionando 'F6' (Ítem Activo del Bot)")
            keyboard.send('f6')
            
        elif "CARTA" in texto_upper:
            print("⚙️ SISTEMA: Presionando 'F7' (Carta del Bot)")
            keyboard.send('f7')
            
    except Exception as e:
        print(f"\n🚨 ERROR: {e}\n")

# --- 5. HILO DE ESCUCHA (MICRÓFONO) ---
def escuchar_microfono():
    r = sr.Recognizer()
    with sr.Microphone() as source:
        print("\n🎤 Ajustando el ruido de fondo... (hacé silencio un segundo).")
        r.adjust_for_ambient_noise(source)
        print("🎤 ¡Micrófono listo! Mantené presionada la letra 'T' y hablá.\n")
        
        while True:
            if keyboard.is_pressed('t'):
                print("🔴 Escuchando... (hablá ahora)")
                try:
                    audio = r.listen(source, timeout=3, phrase_time_limit=10)
                    print("🔄 Pensando...")
                    texto_hablado = r.recognize_google(audio, language="es-AR")
                    print(f"🗣️ Vos dijiste: '{texto_hablado}'")
                    procesar_orden_usuario(texto_hablado)
                except sr.WaitTimeoutError:
                    print("🔇 No escuché nada.")
                except sr.UnknownValueError:
                    print("❓ No te entendí bien, ¿podés repetir?")
                except Exception as e:
                    print(f"🚨 Error de micrófono: {e}")
                time.sleep(1)
            else:
                time.sleep(0.05)

hilo_chat = threading.Thread(target=escuchar_microfono, daemon=True)
hilo_chat.start()

# --- 6. LECTURA DEL JUEGO (LOG) ---
try:
    with open(ruta_archivo, 'r', encoding='utf-8') as f:
        f.seek(0, 2)
        
        while True:
            linea = f.readline()
            if not linea:
                time.sleep(0.05)
                continue
                
            if "BOTCOOP_IA_DATOS:" in linea:
                try:
                    datos = json.loads(linea.split("BOTCOOP_IA_DATOS:")[1].strip())
                    vida_actual = datos.get('jugador_hp')
                    sala_actual = datos.get('sala_actual')
                    enemigos_vivos = datos.get('enemigos_vivos')
                    hay_jefe = datos.get('hay_jefe')
                    
                    # Actualizamos la memoria global en tiempo real
                    item_actual = datos.get('items_visibles') 
                    
                    hubo_evento = False
                    if item_actual != "Ninguno" and item_actual != ultimo_item:
                        print(f"\n[!] Ítem detectado: {item_actual}")
                        hubo_evento = True
                    if vida_actual < ultima_vida and ultima_vida != -1:
                        print(f"\n[!] ¡Te pegaron! Vida: {vida_actual}")
                        hubo_evento = True
                        
                    if hubo_evento:
                        consejo = pedir_consejo_automatico(vida_actual, sala_actual, item_actual)
                        print(f"🧠 BOT (Automático): {consejo}")
                        hablar_bot(consejo)
                        ultimo_item = item_actual
                    
                    ultima_vida = vida_actual
                except:
                    pass
except FileNotFoundError:
    print("No se encontró el log.")