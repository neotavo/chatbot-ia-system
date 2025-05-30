# MVP BOT IA Whatsapp – GCP

## PASO 1: Crear cuenta en Twilio y activar Sandbox de WhatsApp
1. Ve a https://www.twilio.com/try-twilio y crea una cuenta.
2. Ve al panel y selecciona "Messaging > Try it Out > WhatsApp".
3. Entra a la sección “Sandbox for WhatsApp”: https://www.twilio.com/console/sms/whatsapp/sandbox
4. Twilio te dará:
      - Un número de prueba (+1415...)
      - Un código de verificación para que asocies tu WhatsApp (ej: join tough-hill)
      - En tu teléfono envía ese mensaje al número para vincularlo temporalmente.


-----------------------------------------------
-----------------------------------------------

2. Activado Firestore en modo nativo, región: `us-central1`
      - En la consola GCP, ir a: Menú principal > Firestore > Crear base de datos
      - Elegir: Modo nativo / Región: us-central1 / Confirmar
      <img width="1423" alt="Screenshot 2025-05-25 at 6 23 11 PM" src="https://github.com/user-attachments/assets/cd837799-2094-41ef-aba9-82c0ddf4174b" />

3. Crear colección: businesses
      - En la consola de Firestore.
      - Click en "Iniciar colección"
      - ID colección: businesses
      - ID documento: demo-business
      - Agregar los siguientes campos:
        | Campo                | Tipo       | Valor                                    |
        | -------------------- | ---------- | ---------------------------------------- |
        | nombre\_negocio      | string     | Clínica BellaVida                        |
        | rubro                | string     | clínica estética                         |
        | descripcion          | string     | Tratamientos faciales y depilación láser |
        | horario\_atencion    | mapa (map) | Ver valores abajo                        |
        | feriados\_especiales | array      | `["2025-12-25", "2026-01-01"]`           |

      - Dentro de horario_atencion agrega:
        | Clave     | Valor       |
        | --------- | ----------- |
        | lunes     | 09:00-18:00 |
        | martes    | 09:00-18:00 |
        | miércoles | 09:00-18:00 |
        | jueves    | 09:00-18:00 |
        | viernes   | 09:00-18:00 |
        | sábado    | Cerrado     |
        | domingo   | Cerrado     |
        <img width="1173" alt="Screenshot 2025-05-27 at 10 08 29 PM" src="https://github.com/user-attachments/assets/f13ae6ec-1090-4027-b9b4-502d32eb3d62" />


# Backend mínimo funcional
Estructura esperada
```css
chatbot-ia-system/
├── backend/
│   └── main.py
├── requirements.txt 

```
1.  Archivo requirements.txt (nivel raíz)
Debe tener estos archivos:
```txt
fastapi
uvicorn
google-cloud-firestore
openai
python-dotenv

```
📌 python-dotenv se usará para cargar claves desde un archivo .env.
2. Crear archivo .env (NO lo subas a GitHub)
- En el terminal hay que ir al folder del proyecto:
```bash
cd ~/ruta/del/proyecto/chatbot-ia-system

```
- Ejecutar el siguiente comando:
```bash
cat <<EOF > .env
OPENAI_API_KEY=sk-xxxxxxxxxxxxxxxxxxxxx
GOOGLE_PROJECT_ID=chatbot-dev-460922
BUSINESS_ID=demo-business
EOF

```
⚠️ Reemplaza OPENAI_API_KEY con tu clave real de OpenAI.
- Verifica su contenido:
```bash
cat .env

```
3. Crear main.py en backend/
- Código paso a paso:
```python
# backend/main.py

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from google.cloud import firestore
from openai import OpenAI
import os

db = firestore.Client()
client = OpenAI()
app = FastAPI()

class Pregunta(BaseModel):
    negocio_id: str
    texto: str

@app.post("/preguntar")
def preguntar(pregunta: Pregunta):
    # Buscar el negocio según el ID
    negocio_ref = db.collection("businesses").document(pregunta.negocio_id)
    doc = negocio_ref.get()
    if not doc.exists:
        raise HTTPException(status_code=404, detail="Negocio no encontrado")
    
    negocio = doc.to_dict()

    # Revisar si la pregunta ya existe
    preguntas_ref = negocio_ref.collection("preguntas")
    consulta = preguntas_ref.where("texto", "==", pregunta.texto).limit(1).stream()
    pregunta_existente = next(consulta, None)

    if pregunta_existente:
        datos = pregunta_existente.to_dict()
        return {
            "respuesta": datos["respuesta"],
            "origen": "firestore"
        }

    # Construir el prompt con los datos del negocio
    horario = negocio.get("horario_atencion", {})
    feriados = negocio.get("feriados_especiales", [])
    prompt = f"""
Eres el asistente virtual del negocio '{negocio['nombre_negocio']}'.
Este negocio se dedica a: {negocio['descripcion']} ({negocio['rubro']}).

Horario de atención semanal:
{chr(10).join([f"{dia}: {hora}" for dia, hora in horario.items()])}
Feriados especiales donde está cerrado: {', '.join(feriados)}

Cliente pregunta: "{pregunta.texto}"

Responde con amabilidad y precisión. Si el día consultado es feriado, informa que el negocio está cerrado.
"""

    # Consultar a OpenAI
    try:
        respuesta = client.chat.completions.create(
            model="gpt-3.5-turbo",
            messages=[{"role": "user", "content": prompt}],
            temperature=0.7
        )
        respuesta_final = respuesta.choices[0].message.content
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error al consultar OpenAI: {e}")

    # Guardar en Firestore
    preguntas_ref.add({
        "texto": pregunta.texto,
        "respuesta": respuesta_final
    })

    return {
        "respuesta": respuesta_final,
        "origen": "openai"
    }

```

4. Probar localmente (sin Docker)
- Ejecutar el **módulo `venv`** de Python para crear un **entorno virtual aislado** (si funciona FastAPI no ejecutar):
```bash
python3 -m venv venv
source venv/bin/activate

```
- Reinstalar dependencias (si funciona FastAPI no ejecutar):
```bash
pip install --upgrade pip setuptools
pip install -r requirements.txt

```
```bash
export OPENAI_API_KEY="tu-clave-secreta-de-openai"

```
- Ejecutar el servidor con FastAPI:
```bash
uvicorn backend.main:app --reload --port 8080

```

Luego abre en tu navegador:
👉 http://localhost:8080/docs

Ahí puedes probar el endpoint /preguntar.

Ejemplo de JSON de prueba:
```json
{
  "negocio_id": "demo-business",
  "texto": "¿Atienden el 1 de enero?"
}

```
5. Solución si no funciona correctamente
- En el terminal ejecuta:
```bash
gcloud auth application-default login

```
- Esto abrirá tu navegador y te pedirá que inicies sesión con tu cuenta de Google (la que tiene acceso a tu proyecto GCP).
- Luego, Google creará un archivo de credenciales en:
```bash
~/.config/gcloud/application_default_credentials.json

```
<img width="1348" alt="Screenshot 2025-05-28 at 9 46 34 PM" src="https://github.com/user-attachments/assets/c9924a7f-18bd-4e7c-8b44-f90176c1f2a7" />
- Asegúrate de estar autenticado con el usuario correcto (Verifica que el usuario activo (*) sea el correcto (el que tiene acceso al proyecto GCP chatbot-dev).
```bash
gcloud auth list

```
- Si no lo es, cambia con:
```bash
gcloud auth login

```
- Confirma que el proyecto correcto está activo:
```bash
gcloud config list

```
- Si el proyecto chatbot-dev no aparece, configúralo así:
```bash
gcloud config set project chatbot-dev-460922

```
- Otorga permisos al SDK para acceder a Firestore:
  - Reemplaza "gdacggcp7@gmail.com" por tu correo real (el que usaste con gcloud auth login).
  - Este permiso (roles/datastore.user) permite leer/escribir en Firestore.     
```bash
gcloud projects add-iam-policy-binding chatbot-dev-460922 \
  --member="user:gdacggcp7@gmail.com" \
  --role="roles/datastore.user"

```
- Reinicia tu backend:
```bash
uvicorn backend.main:app --reload --port 8080

```

Luego abre en tu navegador:
👉 http://localhost:8080/docs

Ahí puedes probar el endpoint /preguntar.

