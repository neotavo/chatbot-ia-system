# MVP BOT IA – GCP

## Día 1 (25 de mayo) – Configuración inicial
# Crear proyecto GCP (chatbot-dev)
1. Crear proyeto en GCP
      - Ve a https://console.cloud.google.com/
2. skjidfv
  dfnvkdjfv
  
3.  
4. 
5. 
      ✅ PARTE 1 – Crear proyecto y Firestore
      A. Crear proyecto en GCP
        1. Ve a https://console.cloud.google.com/
        2. Arriba haz clic en "Seleccionar proyecto" > "Nuevo proyecto"
        3. Nombre: chatbot-dev
        <img width="385" alt="Screenshot 2025-05-25 at 6 05 01 PM" src="https://github.com/user-attachments/assets/8d1059fe-852f-47cb-8674-4597c5ae1bbb" />



Ubicación: tu organización o cuenta personal

Espera a que se cree (~30 segundos)
  
- [x] Activado Firestore en modo nativo, región: `us-central1`
- [x] Instalado Google Cloud SDK
- [x] Instalado VSCode y extensiones
- [x] Estructura inicial del proyecto

---------------
---------------
## Día 2 – 


# Load CDC data from MySQL to BigQuery with Pub/Sub (Apache Kafka)

This is done with GCP services

## Characteristics (debo agregar mas cosas aqui)

- Fácil de usar.
- Compatible con múltiples plataformas.

## Creating a MySQL Instance with command
  - Ensure that your MySQL version supports CDC ([Change Data Capture](docs/CDC.md)), which is only available on MySQL 5.7 and above.
  - Consider using SSD for storage instead of HDD for better performance, especially if your CDC instance will handle a high volume of data.
  - Binary replication must be configured for CDC to work properly, this must be done after the instance has been created using the Cloud SQL console (binlog).

1. Create MySQL instance:  
```bash
gcloud sql instances create mysql-instance-source \
--project=annular-axe-443319-j1 \
--database-version=MYSQL_8_0_39 \
--tier=db-g1-small \
--region=us-central1 \
--root-password=packt123 \
--availability-type=zonal \
--storage-size=10GB \
--storage-type=SSD

```

2. Enable Binlog:

**Before enabling Binlog:** We need to enable automatic backups on the MySQL instance, as it is a previous step to enable the Binlog, otherwise an error will appear. You can do this by running this command. --backup-start-time=00:00: Set a schedule to start backups (you can adjust it according to your needs).
```bash
gcloud sql instances patch mysql-instance-source \
    --backup-start-time=00:00

```
**Enable Binlog:**
```bash
gcloud sql instances patch mysql-instance-source \
    --enable-bin-log

```
**Enable Binlog (Another way):**
```bash
gcloud sql instances patch mysql-instance-source \
    --database-flags=log_bin=ON,binlog_format=ROW,binlog_row_image=FULL

```
**Restart service:** Some settings, such as database flags, require an instance restart to take effect.
```bash
gcloud sql instances restart mysql-instance-source

```
**Verify that Binlog is enabled (1):** Connect to the MySQL instance.
```bash
gcloud sql connect mysql-instance-source --user=root

```
**Verify that Binlog is enabled (2):** Run the command to validate.
```sql
SHOW VARIABLES LIKE 'log_bin';
SHOW VARIABLES LIKE 'binlog_format';
SHOW VARIABLES LIKE 'binlog_row_image';

```
You should see the following:
- log_bin: ON
- binlog_format: ROW
- binlog_row_image: FULL
  
## Adding data to MySQL
  - A database with a table will be created.
  - Insert test data in a simple way.
  - Generate data with a SQL script.
  - Configure some details in Mysql

1. Create database:  
```sql
CREATE DATABASE customers_db; 

```
2. Prepare the table: Create a table in your MySQL database.
```sql
CREATE TABLE customers_db.customers (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100),
    email VARCHAR(100),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

```
3. Inserting Test Data: You can insert multiple data manually or use a SQL script to load bulk data.
   
**Option 1 - Inserting Manually:**
```sql
INSERT INTO customers_db.customers (name, email) VALUES
('Alice', 'alice@example.com'),
('Bob', 'bob@example.com'),
('Charlie', 'charlie@example.com'),
('Diana', 'diana@example.com');

```
**Option 2 - Generating data with a SQL script:**: This will generate 100.000 rows in the table.
**Step1:**
```sql
USE customers_db;

```
**Step2:**
```sql
DELIMITER $$

CREATE PROCEDURE GenerateTestData()
BEGIN
    DECLARE i INT DEFAULT 1;

    WHILE i <= 100000 DO
        INSERT INTO customers_db.customers (name, email)
        VALUES (CONCAT('User', i), CONCAT('user', i, '@example.com'));
        SET i = i + 1;
    END WHILE;
END$$

DELIMITER ;

```
**Step3:**
```sql
CALL GenerateTestData();

```

4. Enable Access to MySQL Instance:
   
**Configures the list of networks authorized to access the instance:** This command opens access to the Cloud SQL instance to all IP addresses (0.0.0.0/0). In other words, anyone with the instance's public IP address and the correct credentials will be able to access the MySQL database.
```bash
gcloud sql instances patch mysql-instance-source \
    --authorized-networks=0.0.0.0/0

```
**Get MySQL Instance IP:**
```bash
gcloud sql instances describe mysql-instance-source \
    --format="get(ipAddresses.ipAddress)"

```
**Test connectivity from Cloud Shell:**
```bash
mysql -h 34.134.26.73 -P 3306 -u root -p

```
**Installing the MySQL Connector Module:** Install the mysql-connector-python package into your local environment using pip3 (the Python 3 package manager).
```bash
pip3 install mysql-connector-python --user

```
**Verify the installation:**
```bash
python3 -c "import mysql.connector; print('MySQL Connector installed successfully')"

```

## Configure PubSub flow

1. Creating a topic and subscription in pubsub:

**Topic creation:** Create a topic in Pub/Sub where events will be published.
```bash
gcloud pubsub topics create simple-topic

```
**Subscription creation:** Create a subscription in Pub/Sub that will be responsible for receiving the events published on the topic.
```bash
gcloud pubsub subscriptions create simple-subscription \
    --topic=simple-topic

```
2. Install the Google Cloud PubSub library for Python:
   
**Subscription creation:** Create a subscription in Pub/Sub that will be responsible for receiving the events published on the topic.
```bash
pip3 install google-cloud-pubsub --user

```
**Verify the installation:**
```bash
python3 -c "from google.cloud import pubsub_v1; print('Pub/Sub installed successfully')"

```
3. Create python script publish_mysql_events.py: The script detects changes in the MySQL table and publishes them to Pub/Sub (identifies insert and update)

**Create file publish_mysql_events.py:**
```bash
nano publish_mysql_events.py

```
**Contents of the publish_mysql_events.py script:** 
```python
import mysql.connector
import json
import datetime
from google.cloud import pubsub_v1

# Configure your connection to MySQL
db_config = {
    'host': '34.28.7.196',
    'user': 'root',
    'password': 'packt123',
    'database': 'customers_db'
}

# Configure the Pub/Sub client
project_id = 'annular-axe-443319-j1'
topic_id = 'simple-topic'
publisher = pubsub_v1.PublisherClient()
topic_path = publisher.topic_path(project_id, topic_id)

# Function to publish events to Pub/Sub
def publish_to_pubsub(event):
    # Convert datetime values ​​to text strings
    for key, value in event.items():
        if isinstance(value, (datetime.datetime, datetime.date)):
            event[key] = value.isoformat()  # Convert to ISO 8601 format

    # Serialize to JSON
    message = json.dumps(event).encode('utf-8')

    # Print the event before publishing it
    print(f"Publishing event: {json.dumps(event, indent=4)}")

    # Publish message to Pub/Sub
    future = publisher.publish(topic_path, message)
    print(f'Published message ID: {future.result()}')

# Function to listen for changes in MySQL (insert and update only)
def listen_for_changes():
    conn = mysql.connector.connect(**db_config)
    cursor = conn.cursor(dictionary=True)

    last_updated = '1970-01-01T00:00:00'  # Initializes the last processed update date

    while True:
        cursor.execute(f"SELECT * FROM customers WHERE updated_at > '{last_updated}'")
        rows = cursor.fetchall()

        for row in rows:
            publish_to_pubsub(row)
            last_updated = row['updated_at']  # Update the last processed update date

        conn.commit()

# Run the main function
if __name__ == "__main__":
    listen_for_changes()


```
**Change execution permissions:** This command converts the publish_mysql_events.py file into an executable.
```bash
chmod +x publish_mysql_events.py

```
**The script will be executed later in the "Execution" section**

## Prepare bucket in Cloud Storage

1. Create bucket: Must be a unique name (gs://simple-dataflow-temp/tmp)
**Create bucket:** gs://simple-dataflow-temp
```bash
gcloud storage buckets create gs://simple-dataflow-temp \
    --location=us-central1 \
    --default-storage-class=STANDARD

```
**Create directory /tmp (Step1):** Once the bucket is created, you must create a file called somefile.txt (Create an empty file, if you want to edit it you must go with the nano function)
```bash
touch somefile.txt

```
**Create directory /tmp (Step2):** Once the file is created, the easiest way to create a "directory structure" is to upload a file to have the /tmp directory:
```bash
gsutil cp somefile.txt gs://simple-dataflow-temp/tmp2/

```
**List bucket names only:** 
```bash
gcloud storage buckets list --format="value(name)"

```
**List in more compact table format::** 
```bash
gcloud storage buckets list --format="table(name, location, storageClass)"

```

2. 
3.  

## Prepare dataset and table in BigQuery




---------------
---------------
---------------
---------------
---------------



**Assigns a public IP to the mysql-instance-source Cloud SQL instance:**This allows the instance to be accessible from the Internet (for example, from your local machine or from other services outside of Google Cloud).
```bash
gcloud sql instances patch mysql-instance-source --assign-ip

```
**Authorize your IP address:**Add IP
```bash
gcloud sql instances patch mysql-instance-source \
    --authorized-networks=$(curl -s ifconfig.me)/32

```
**Check if your IP is in the authorized networks of the instance::**
```bash
gcloud sql instances describe mysql-instance-source --format="json(settings.ipConfiguration.authorizedNetworks)"

```
**Create a new user:**named gus in the Cloud SQL instance mysql-instance-source
```bash
gcloud sql users create gus --instance=mysql-instance-source --password=mila1982

```
**Validates the instance connection with the new user:**
```bash
mysql -u gus -p -h 34.72.106.53 -P 3306

```
**Cloud SQL Auth Proxy:**Grants execute permissions and moves the Cloud SQL Auth Proxy binary to a standard location on the system.
```bash
curl -o cloud_sql_proxy https://dl.google.com/cloudsql/cloud_sql_proxy.linux.amd64
chmod +x cloud_sql_proxy
sudo mv cloud_sql_proxy /usr/local/bin/

```
**Get region instance:**
```bash
gcloud sql instances describe mysql-instance-source --format="get(region)"

```
**Start the Cloud SQL Auth Proxy:**allows your local machine (or any other application) to connect to a Cloud SQL instance through a secure tunnel
```bash
cloud_sql_proxy -instances=annular-axe-443319-j1:us-central1:mysql-instance-source=tcp:3306 &

```
**Create a BigQuery connection to Cloud SQL (Mysql):**
```bash
bq mk --connection \
    --display_name="MySQL_Connection" \
    --connection_type=CLOUD_SQL \
    --project_id=annular-axe-443319-j1 \
    --location=us-central1 \
    --properties='{"instanceId":"annular-axe-443319-j1:us-central1:mysql-instance-source","database":"customers_db"}'





este comando sale error: 

bq show --connection --project_id=annular-axe-443319-j1 --connection=MySQL_Connection



```





------------------------------------------------

## Configure Pub/Sub
  - Topic and subscription will be created.
  - Configure Datastream to capture changes.
  - Testing the configuration.
    
1. Configure Pub/Sub:
   
**Create a topic in Pub/Sub:** This topic will receive MySQL events.
```bash
gcloud pubsub topics create cdc-topic

```
**Create a subscription in Pub/Sub:** If you need to process events in a consumer, create a subscription.
```bash
gcloud pubsub subscriptions create cdc-subscription \
    --topic=cdc-topic

```
2. Configure Datastream to capture changes: Google Datastream is a native service for capturing data from MySQL and PostgreSQL to Pub/Sub or BigQuery.

**Habilitar Datastream API:** First, enable the API in your project.
```bash
gcloud services enable datastream.googleapis.com

```
**Create a source connection (Cloud SQL):** Create the source connection, use Datastream to define a connection to your instance.
```bash
gcloud datastream connection-profiles create mysql-source-connection \
    --location=us-central1 \
    --type=mysql \
    --display-name="MySQL Source Connection" \
    --mysql-hostname=34.72.106.53 \
    --mysql-port=3306 \
    --mysql-username=root \
    --mysql-password=packt123

AQUI TENGO ERROR, HASTA AQUI QUEDO

gcloud compute firewall-rules create allow-mysqlv2 \
    --allow=tcp:3306 \
    --direction=INGRESS \
    --target-tags=mysql-source-connection  \
    --source-ranges=0.0.0.0/0

```

```bash















    









    




34.134.202.82

3.
4. **Delete record:**
Validación del perfil de conexión
Para asegurarte de que el perfil de conexión se creó correctamente, sigue estos pasos:

Lista los perfiles de conexión existentes: Ejecuta este comando:

bash
Copy code
gcloud datastream connection-profiles list --location=us-central1

Verás una lista de todos los perfiles en la ubicación especificada. Deberías encontrar mysql-source-connection en esa lista.

Consulta detalles del perfil creado: Usa este comando para obtener detalles específicos:

bash
Copy code
gcloud datastream connection-profiles describe mysql-source-connection --location=us-central1
5. 









-------------------------------------------
-------------------------------------------
-------------------------------------------

6. jfjfjf
7. jfjf
8. kkvkkv
9.
10.
11.    or use a SQL script to load bulk data.

12. ---------

13. Part 4
14. Part 5
   
15. Part 6
   ```bash
   git clone https://github.com/usuario/repo.git

ejemplo para agregar fragmento de código
Ejecuta el comando `git clone` para clonar el repositorio.

ejemplo para bash

**Resultado**:
```bash
git clone https://github.com/usuario/repo.git
cd repo
python3 script.py

```

ejemplo python:



### Paso 1: Clonar el repositorio
```bash
git clone https://github.com/usuario/repo.git

```


datastream:
hay que habilitar la Datastream API
habilitar api:
gcloud services enable datastream.googleapis.com
o
gcloud services enable datastream.googleapis.com --project [PROJECT_ID]



validar la API:
gcloud services list --enabled

Busca datastream.googleapis.com en la lista de servicios habilitados.















