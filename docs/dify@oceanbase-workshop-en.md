## Background

Dify is an open-source LLM application development platform. Its intuitive interface integrates AI workflows, RAG pipelines, Agents, model management, observability features, and more, enabling you to quickly transition from prototyping to production. Starting from version 4.3.3, OceanBase supports the storage and retrieval of vector data types. From Dify version 0.11.0, OceanBase is supported as its vector database. By making the necessary modifications in the forked Dify repository [oceanbase-devhub/dify](https://github.com/oceanbase-devhub/dify), Dify now supports using databases with the MySQL protocol to store structured data. As a result, OceanBase, as a multi-model database, can effectively meet Dify's requirements for accessing both structured and vector data, providing strong support for the development and deployment of LLM applications.

## Experiment Environment

- Git
- [Docker](https://docs.docker.com/engine/install/) and [Docker Compose](https://docs.docker.com/compose/install/)
- MySQL Client

## Steps to Deploy Dify with OceanBase

### 1. Deploy OceanBase Database with Docker

#### Start OceanBase Docker Container

You can start an OceanBase database container using the following command:

```bash
docker run --name=ob433 -e MODE=mini -e OB_MEMORY_LIMIT=8G -e OB_DATAFILE_SIZE=10G -e OB_CLUSTER_NAME=ailab2024_dify -e OB_TENANT_PASSWORD=difyai123456 -e OB_SERVER_IP=127.0.0.1 -p 2881:2881 -d quay.io/oceanbase/oceanbase-ce:4.3.3.1-101000012024102216
```

If the above command is executed successfully, the container ID will be printed as follows:

```bash
af5b32e79dc2a862b5574d05a18c1b240dc5923f04435a0e0ec41d70d91a20ee
```

#### Check if OceanBase Database Initialization is Complete

After the container is started, you can check the initialization status of the OceanBase database using the following command:

```bash
docker logs -f ob433
```

The initialization process takes about 2 to 3 minutes. When you see the following message (the `boot success!` at the bottom is required), it means that the OceanBase database initialization is complete:

```bash
cluster scenario: express_oltp
Start observer ok
observer program health check ok
Connect to observer ok
Initialize oceanbase-ce ok
Wait for observer init ok
+----------------------------------------------+
|                 oceanbase-ce                 |
+------------+---------+------+-------+--------+
| ip         | version | port | zone  | status |
+------------+---------+------+-------+--------+
| 172.17.0.2 | 4.3.3.1 | 2881 | zone1 | ACTIVE |
+------------+---------+------+-------+--------+
obclient -h172.17.0.2 -P2881 -uroot -Doceanbase -A

cluster unique id: c17ea619-5a3e-5656-be07-00022aa5b154-19298807cfb-00030304

obcluster running

...

check tenant connectable
tenant is connectable
boot success!
```

Type `Ctrl + C` to exit the log viewing interface.

#### Test Database Deployment (Optional)

You can use the MySQL client to connect to the OceanBase cluster and check the database deployment status.

```bash
mysql -h127.0.0.1 -P2881 -uroot@test -pdifyai123456 -A -e "show databases"
```

If the connection is successful, you will see the following output:

```bash
+--------------------+
| Database           |
+--------------------+
| information_schema |
| mysql              |
| oceanbase          |
| test               |
+--------------------+
```

#### Enable Vector Module by Modifying Parameters

You can enable OceanBase's vector functionality module by setting the `ob_vector_memory_limit_percentage` parameter to a non-zero value for the `test` tenant using the command below.

```bash
mysql -h127.0.0.1 -P2881 -uroot@test -pdifyai123456 -A -e "alter system set ob_vector_memory_limit_percentage = 30"
```

#### Create A New Database

After OceanBase database initialization, only an empty database named `test` is created by default. To store structured data (to meet the requirements of alembic database structure migration) and vector data separately, we need to create another database. For example, you can create a new database named `dify` using the command below.

```bash
mysql -h127.0.0.1 -P2881 -uroot@test -pdifyai123456 -A -e "create database dify"
```

### 2. Clone the Repository

We have made modifications to the MySQL protocol compatibility for Dify version 0.14.2 and uploaded it to our forked code repository.

```bash
git clone https://github.com/oceanbase-devhub/dify.git
```

For the latest code in the `dify` directory, execute the `git pull` command to pull the latest code.

```bash
cd dify
git pull
```

### 3. Pull Docker Images

After entering the `docker` directory in the working directory of Dify, execute `docker compose --profile workshop pull` to pull the required images.

```bash
cd docker
docker compose --profile workshop pull
```

### 4. Configure Environment Variables

In the `docker` directory, there is a `.env.example` file containing several environment variables required for running Dify. We need to fill in some important configuration items.

We provide a script `setup-env.sh` in the `docker/scripts` directory to interactively obtain database connection information, fill it into the `.env` file and complete database connection verification. You just need to execute:

```bash
bash ./scripts/setup-env.sh
```

And then fill in the database connection information as prompted, the general form is as follows:

![Set up environment variables](images/setup-env.jpg)

If both databases are connected successfully during the database connection detection step, it means that the database connection information is filled in correctly and you can proceed to the next step.

![Set up environment variables successfully](images/setup-env-success.jpg)

### 5. Start Dify Containers

Before starting, check if the images pulled in step 2 are ready. If they are ready, you can start the Dify container group using the following command.

```bash
docker compose --profile workshop up -d
```

### 6. Check the Logs

```bash
docker logs -f docker-api-1
docker logs -f docker-worker-1
```

If you see the message `Database migration successful!` in the logs of any of the containers, it means that the database structure upgrade is complete (the other container may have `Database migration skipped` indicating that the database structure migration was skipped in that container). If there are no other `ERROR` messages, you can open the Dify interface normally.

### 7. Visit Dify

By default, the Dify front-end page is started on port `80` of the local machine, which means that you can access the Dify interface by visiting the IP of the current machine. In other words, if I run it on my laptop, I can access the Dify interface by visiting `localhost` in the browser (or the internal IP); if Dify is deployed on a server, you need to access the public IP of the server. The first time you visit the Dify application, you will enter the "Set Admin Account" page, and after setting it up, you can use the account to log in.

![Visit Dify](images/visit-dify-1.png)

![Visit Dify](images/visit-dify-2.png)

![Visit Dify](images/visit-dify-3.png)

## Steps to Build a Document RAG QA Assistant

In this section, we will use the model service provided by Alibaba Cloud Bailing, and use Dify to build a document RAG QA assistant.

### 1. Obtain the API Key from Model Service Providers like OpenAI

You can refer to [OpenAI API](https://platform.openai.com/api-keys) to obtain the API Key for OpenAI.

### 2. Configure Model Providers and System Models

After configuration, we need to set up the model providers and system models in Dify. For example, select the `text-embedding-3-large` model as the default embedding model and `gpt-4o` as the default generation model.

### 3. Create a Knowledge and Upload Documents

#### 3.1 Clone the Documentation Repository

We will clone the open-source documentation repository of the OceanBase database as the data source.

```bash
git clone --single-branch --branch V4.3.4 https://github.com/oceanbase/oceanbase-doc.git ~/oceanbase-doc
```

#### 3.2 Upload Specified Documents to the Knowledge

Back to the homepage, click the "Knowledge" tab in the middle of the top, enter the knowledge management interface, and click "Create Knowledge".

![Configure Knowledge](images/create-knowledge-base-1.png)

In order to save time and reduce the model service call volume, we only process a few documents related to OceanBase vector search, which are located in the `zh-CN/640.ob-vector-search` directory relative to the `oceanbase-doc` directory. We need to upload all the documents in this directory.

![Configure Knowledge](images/create-knowledge-base-2.png)

![Configure Knowledge](images/create-knowledge-base-3.png)

![Configure Knowledge](images/create-knowledge-base-4.png)

Set Index Mode to "High Quality", click "Save & Process".

![Configure Knowledge](images/create-knowledge-base-5.png)

Dify will prompt that the knowledge has been created, and you may see that some documents have been processed here. Click "Go to Document".

![Configure Knowledge](images/create-knowledge-base-6.png)

![Configure Knowledge](images/create-knowledge-base-7.png)

![Configure Knowledge](images/create-knowledge-base-8.png)

### 4. Create a Chat Application and Select the Knowledge

Click the "Studio" tab to enter the application management interface, and click "Create from Blank".

![Build RAG Robot](images/create-application-1.png)

![Build RAG Robot](images/create-application-2.png)

You can fill in the application name by yourself, such as "OB Vector Document Assistant". After entering, click the "Create" button. After the creation is completed, you will enter the application orchestration interface.

![Build RAG Robot](images/create-application-3.png)

Click the "Add" button in the "Context" card, select the knowledge we just created, and click the "Add" button.

![Build RAG Robot](images/create-application-4.png)

![Build RAG Robot](images/create-application-5.png)

![Build RAG Robot](images/create-application-6.png)

随后，在提示词的输入框中填写如下的提示词：

```bash
You are an assistant focused on answering user questions. Your goal is to answer user questions using possible historical conversations and retrieved document snippets.

Task description: Try to answer user questions based on possible historical conversations, user questions, and retrieved document snippets. If all documents cannot solve the user's question, first consider the rationality of the user's question. If the user's question is unreasonable, it needs to be corrected. If the user's question is reasonable but no relevant information can be found, apologize and give a possible answer based on internal knowledge. If the information in the document can answer the user's question, strictly answer the question based on the document information.

Answer requirements:
- If all documents cannot solve the user's question, first consider the rationality of the user's question. If the user's question is unreasonable, please answer: "Your question may be misunderstood. In fact, as far as I know... (provide correct information)". If the user's question is reasonable but no relevant information can be found, please answer: "Sorry, I can't find information to solve this problem from the retrieved documents."
- If the information in the document can answer the user's question, please answer: "According to the information in the document library,... (answer the user's question strictly based on the document information)". If the answer can be found in a document, please directly indicate the name of the document and the title of the paragraph (do not indicate the fragment number) when answering.
- If a document fragment contains code, please pay attention to it and include the code as much as possible in the answer to the user. Please refer to the document information completely to answer the user's question, and do not make up facts.
- If you need to combine fragments of information from multiple documents, please try to give a comprehensive and professional answer after a comprehensive summary and understanding.
- Answer the user's question in points and details as much as possible, and the answer should not be too short.
```

![Build RAG Robot](images/create-application-7.png)

And you can start debugging the application in the chat box on the right, for example, ask "Please introduce the vector function of OceanBase".

![Build RAG Robot](images/create-application-8.png)

### 5. Publish the Application

Click the "Run" button under "Publish" in the upper right corner of the application details to open the exclusive page of the application.

![Publish the Application](images/publish-the-application-1.png)

Click the "Start Chat" button to start chatting.

![Publish the Application](images/publish-the-application-2.png)

If you deploy Dify on a server, you can also share the link of the application with your friends and let them try it out!

Congratulations! 🎉 You have successfully built your own LLM application platform and intelligent agent application with Dify + OceanBase!

## Appendix

### What does the setup-env.sh script do?

`setup-env.sh` script first copies the example file to the effective one.

```bash
cp .env.example .env
```

#### 1. Modify the DB_XXX Configuration Items

This part of the configuration is for the relational database. The `171-189` lines in `.env.example` are as follows,

```bash
# ------------------------------
# Database Configuration
# The database uses PostgreSQL. Please use the public schema.
# It is consistent with the configuration in the 'db' service below.
# ------------------------------

DB_PASSWORD=******
DB_DATABASE=dify

# For MySQL Database
# SQLALCHEMY_DATABASE_URI_SCHEME=mysql+pymysql
# DB_USERNAME=root
# DB_HOST=mysql-db
# DB_PORT=3306

# For PostgresQL (By default)
DB_USERNAME=postgres
DB_HOST=db
DB_PORT=5432
```

The script modify the configuration as follows,

```bash
# ------------------------------
# Database Configuration
# The database uses PostgreSQL. Please use the public schema.
# It is consistent with the configuration in the 'db' service below.
# ------------------------------

DB_PASSWORD=****** # Updated
DB_DATABASE=****** # Updated

# For MySQL Database
SQLALCHEMY_DATABASE_URI_SCHEME=mysql+pymysql # Uncomment this line. This is very important
DB_USERNAME=**** # Updated
DB_HOST=******** # Updated
DB_PORT=**** # Updated

# For PostgresQL (By default)
# DB_USERNAME=postgres
# DB_HOST=db
# DB_PORT=5432
```

#### 2. Modify the OCEANBASE_VECTOR_XXX Configuration Items

This section explains the configuration of OceanBase as the vector database for Dify. It is important to note that the `OCEANBASE_VECTOR_DATABASE` variable **<u>must not</u>** be the same as the `DB_DATABASE` specified in Step `1`. This is because the metadata database requires schema upgrades, which involve comparing the structure of all tables in the database to generate schema migration scripts. If a vector table is included, it may interfere with the normal operation of the schema migration tool (alembic).

The following five variables need to be updated with your OceanBase database connection details. However, note that if you are using an OceanBase database deployed on your local machine, the `xxx_HOST` should be set to `172.17.0.1`. (For macOS, use `host.docker.internal` instead.)

```bash
# OceanBase Vector configuration, only available when VECTOR_STORE is `oceanbase`
OCEANBASE_VECTOR_HOST=***
OCEANBASE_VECTOR_PORT=***
OCEANBASE_VECTOR_USER=***
OCEANBASE_VECTOR_PASSWORD=***
OCEANBASE_VECTOR_DATABASE=***
```

#### 3. Modify the VECTOR_STORE Option

Update the value of the `VECTOR_STORE` variable in the `.env` file to `oceanbase` to use OceanBase as the vector database for Dify.

#### 4. Verify the Database Connection

After modifying the `.env` file, use the `setup-env.sh` script to verify whether the database connection is functioning correctly with the following command:

```bash
mysql -h1.2.3.4 -P3306 -uroot -pxxxx -Doceanbase -e "SHOW TABLES"
```