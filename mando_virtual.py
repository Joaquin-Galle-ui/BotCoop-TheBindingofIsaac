import vgamepad as vg
import time

print("Iniciando conexión con el sistema operativo...")

# Esto crea un mando de Xbox 360 a nivel de Windows (ATENCION, esto se utiliza para que el juego piense
# que existe otro jugador y con ello coloque las vidas e items aparte y no lo sobreponga)
gamepad = vg.VX360Gamepad()

print("¡Mando de Xbox 360 virtual conectado exitosamente!")
print("Deberías haber escuchado el sonido de 'USB conectado' de Windows.")
print("Deja esta ventana abierta y abre The Binding of Isaac.")
print("Para apagar el mando, presiona Ctrl+C aquí.")

# Un bucle infinito para que el mando siga existiendo mientras juegas
try:
    while True:
        time.sleep(1)
except KeyboardInterrupt:
    print("\nDesconectando mando virtual... ¡Adiós!")