## 实验背景

Dify 是一个开源的 LLM 应用开发平台。其直观的界面结合了 AI 工作流、RAG 管道、Agent、模型管理、可观测性功能等，让您可以快速从原型到生产。OceanBase 从 4.3.3 版本开始支持了向量数据类型的存储和检索，在 Dify 0.11.0 中开始支持使用 OceanBase 作为其向量数据库。通过我们在 Fork 出来的 Dify 代码仓库 [oceanbase-devhub/dify](https://github.com/oceanbase-devhub/dify) 中进行相应的修改之后，Dify 支持使用 MySQL 协议的数据库存储结构化数据。自此，OceanBase 作为一款多模数据库，可以很好地支持 Dify 对结构化数据和向量数据的存取需求，有力地支撑其上 LLM 应用的开发和落地。

## 实验环境

- Git
- [Docker](https://docs.docker.com/engine/install/) 和 [Docker Compose](https://docs.docker.com/compose/install/)
- MySQL 客户端（可选，如果使用 Docker 部署 OceanBase 则必须）

## 平台搭建步骤

### 1. 获取 OceanBase 数据库

进行实验之前，我们需要先获取 OceanBase 数据库，目前可行的方式有两种：使用 OBCloud 实例或者使用 Docker 本地部署单机版 OceanBase 数据库。

#### 1.1 使用 OBCloud 实例

##### 1.1.1 注册并开通实例

进入[OB Cloud 云数据库 365 天免费试用](https://www.oceanbase.com/free-trial)页面，点击“立即试用”按钮，注册并登录账号，填写相关信息，开通实例，等待创建完成。

##### 1.1.2 获取数据库实例连接串

进入实例详情页的“实例工作台”，点击“连接”-“获取连接串”按钮来获取数据库连接串，将其中的连接信息填入后续步骤中创建的 .env 文件内。

![获取数据库连接串](images/get-connection-info.png)

##### 1.1.3 创建多个数据库

为了分别存放结构化数据（满足 alembic 的数据库结构迁移方案要求）和向量数据，我们需要至少创建两个数据库。可在实例详情页面中的“数据库管理”功能中创建数据库。

![在 OBCloud 上创建多个数据库](images/create-multiple-db.png)

#### 1.2 使用 Docker 部署单机版 OceanBase

##### 1.2.1 启动 OceanBase 容器

如果你是第一次登录动手实战营提供的机器，你需要通过以下命令启动 Docker 服务：

```bash
systemctl start docker
```

随后您可以使用以下命令启动一个 OceanBase docker 容器：

```bash
docker run --name=ob433 -e MODE=mini -e OB_MEMORY_LIMIT=8G -e OB_DATAFILE_SIZE=10G -e OB_CLUSTER_NAME=ailab2024_dify -e OB_SERVER_IP=127.0.0.1 -p 2881:2881 -d quay.io/oceanbase/oceanbase-ce:4.3.3.1-101000012024102216
```

如果上述命令执行成功，将会打印容器 ID，如下所示：

```bash
af5b32e79dc2a862b5574d05a18c1b240dc5923f04435a0e0ec41d70d91a20ee
```

##### 1.2.2 检查 OceanBase 数据库初始化是否完成

容器启动后，您可以使用以下命令检查 OceanBase 数据库初始化状态：

```bash
docker logs -f ob433
```

初始化过程大约需要 2 ~ 3 分钟。当您看到以下消息（底部的 `boot success!` 是必须的）时，说明 OceanBase 数据库初始化完成：

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

使用 `Ctrl + C` 退出日志查看界面。

##### 1.2.3 测试数据库部署情况（可选）

可以使用 mysql 客户端连接到 OceanBase 集群，检查数据库部署情况。

```bash
mysql -h127.0.0.1 -P2881 -uroot@test -A -e "show databases"
```

如果部署成功，您将看到以下输出：

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

##### 1.2.4 修改参数启用向量模块

可通过下面的命令将`test`租户下的`ob_vector_memory_limit_percentage`参数设置为非零值，以开启 OceanBase 的向量功能模块。

```bash
mysql -h127.0.0.1 -P2881 -uroot@test -A -e "alter system set ob_vector_memory_limit_percentage = 30"
```

##### 1.2.5 新增一个数据库

OceanBase 数据库初始化之后默认只会创建一个名为`test`的空数据库，为了分别存放结构化数据（满足 alembic 的数据库结构迁移方案要求）和向量数据，我们需要再创建一个数据库。例如可通过下面的命令创建一个新的数据库，名为`meta`。

```bash
mysql -h127.0.0.1 -P2881 -uroot@test -A -e "create database meta"
```

### 2. 克隆项目

我们针对 Dify 的 0.12.1 版本进行了 MySQL 协议兼容的修改，并且上传到了我们 fork 的代码仓库中。大家网络条件好的话推荐克隆 Github 上的版本，否则克隆 Gitee 上的版本。

```bash
git clone https://github.com/oceanbase-devhub/dify.git
# 如果网络条件差
git clone https://gitee.com/oceanbase-devhub/dify.git
```

### 3. 拉取 Docker 镜像

进入到 dify 的工作目录中的`docker`目录下，执行`docker compose --profile workshop pull`，拉取所需要的镜像，这些镜像不一定都能够顺利拉取，请大家先自行寻求解决方案。

参考命令

```bash
cd dify/docker
docker compose --profile workshop pull
```

### 4. 修改环境变量

在`docker`目录下存放着一个`.env.example`文件，其中包含了若干 Dify 运行所需的环境变量，我们需要在这里把几个重要的配置项填写上。先把示例文件复制成为正式的版本。

```bash
cp .env.example .env
```

#### 4.1 修改 DB_XXX 配置项

这部分配置项是关系型数据库的配置项，`.env.example`中的`171-189`行是这样的，

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

需要改成如下所示的样子，也就是改成用`MySQL`而不是 PG 作为 Dify 的元数据库。需要注意的是，如果使用的是在本地机器上部署的 OceanBase 数据库，`xxx_HOST` 需要填写`172.17.0.1`。

```bash
# ------------------------------
# Database Configuration
# The database uses PostgreSQL. Please use the public schema.
# It is consistent with the configuration in the 'db' service below.
# ------------------------------

DB_PASSWORD=****** # 更新密码
DB_DATABASE=****** # 更新数据库名

# For MySQL Database
SQLALCHEMY_DATABASE_URI_SCHEME=mysql+pymysql # 取消这一行的注释很关键！
DB_USERNAME=**** # 更新用户名
DB_HOST=******** # 更新 Host
DB_PORT=**** # 更新端口

# For PostgresQL (By default)
# DB_USERNAME=postgres
# DB_HOST=db
# DB_PORT=5432
```

#### 4.2 修改 OCEANBASE_VECTOR_XXX 配置项

这个是将 OceanBase 作为 Dify 的向量数据库的配置，这里需要注意的是`OCEANBASE_VECTOR_DATABASE`变量**<u>不能</u>**和`4.1`步骤中填写的`DB_DATABASE`一致，因为元数据库是需要做数据库结构升级的，每次都需要比对库中所有表的结构来生成结构升级脚本，如果有向量表在其中会影响数据库结构升级工具(alembic)的正常工作。

这五个变量需要修改成你的 OceanBase 数据库的连接信息，OBCloud 也好，Docker 部署的版本也好。但需要注意的是，如果使用的是在本地机器上部署的 OceanBase 数据库，`xxx_HOST`需要填写`172.17.0.1`。

```bash
# OceanBase Vector configuration, only available when VECTOR_STORE is `oceanbase`
OCEANBASE_VECTOR_HOST=***
OCEANBASE_VECTOR_PORT=***
OCEANBASE_VECTOR_USER=***
OCEANBASE_VECTOR_PASSWORD=***
OCEANBASE_VECTOR_DATABASE=***
```

#### 4.3 修改 VECTOR_STORE 选项

将 .env 中的`VECTOR_STORE`变量的值改为`oceanbase`，选用 oceanbase 作为 Dify 的向量数据库。

### 5. 启动 Dify 容器组

启动之前先看看第 2 步开始拉取的镜像是否就绪，如果已经完成，可以使用下列命令启动 Dify 的容器组。

```bash
docker compose --profile workshop up -d
```

### 6. 查看 Dify 后端服务日志

```bash
docker logs -f docker-api-1
docker logs -f docker-worker-1
```

如果在其中任意一个容器的日志中看到了`Database migration successful!`这一条信息，则说明数据库结构升级完成（另一个容器中可能会有`Database migration skipped`表示在该容器中跳过了数据库结构迁移），如果没有其他`ERROR`信息，则说明可以正常打开 Dify 界面了。

### 7. 访问 Dify 应用

默认情况下，Dify 的前端页面会启动在本机的`80`端口上，也就是说可以通过访问当前机器的 IP 来访问 Dify 的界面。也就是说如果我在笔记本上运行的话，我在浏览器上访问`localhost`即可（或者是内网 IP）；如果在服务器上部署 Dify，则需要访问服务器的公网 IP。初次访问 Dify 应用会进入“设置管理员账户”的页面，设置完成后即可使用该账号登录。

![访问 Dify 应用](images/visit-dify-1.png)

![访问 Dify 应用](images/visit-dify-2.png)

![访问 Dify 应用](images/visit-dify-3.png)

## 应用开发步骤

在该步骤当中我们将使用阿里云百炼的模型服务，通过 Dify 搭建一个文档 RAG 问答助手。

### 1. 开通阿里云百炼模型调用服务并获取 API KEY

首先，我们需要注册[阿里云百炼](https://bailian.console.aliyun.com/)账号，开通模型调用服务并获取 API Key

![开通百炼模型调用服务](images/bailian-model-call-1.png)

![开通百炼模型调用服务](images/bailian-model-call-2.png)

![获取百炼 API KEY](images/bailian-get-api-key-1.png)

![获取百炼 API KEY](images/bailian-get-api-key-2.png)

### 2. 设置模型供应商和系统模型

![设置模型供应商](images/set-model-provider-1.png)

![设置模型供应商](images/set-model-provider-2.png)

![设置模型供应商](images/set-model-provider-3.png)

![设置模型供应商](images/set-model-provider-4.png)

添加模型`qwen-turbo-2024-11-01`

![设置模型供应商](images/set-model-provider-5.png)

完成系统模型设置，将系统推理模型设置为`qwen-turbo-2024-11-01`，Embedding 模型设置为`text-embedding-v3`

![设置系统模型](images/set-model-provider-6.png)

![设置系统模型](images/set-model-provider-7.png)

### 3. 创建知识库并上传文档

#### 3.1 克隆文档仓库

我们将 OceanBase 数据库的开源文档仓库克隆下来，作为数据来源。

```bash
git clone --single-branch --branch V4.3.4 https://github.com/oceanbase/oceanbase-doc.git ~/oceanbase-doc
# 如果您访问 Github 仓库速度较慢，可以使用以下命令克隆 Gitee 的镜像版本
git clone --single-branch --branch V4.3.4 https://gitee.com/oceanbase-devhub/oceanbase-doc.git ~/oceanbase-doc
```

#### 3.2 将指定文档上传到知识库中

回到首页，顶端中部的“知识库”标签页，进入知识库管理界面，点击创建知识库。

![配置知识库](images/create-knowledge-base-1.png)

为了节省时间和模型服务调用量，我们仅处理 OceanBase 向量检索有关的几篇文档，这些文档相对于`oceanbase-doc`目录的相对路径是`zh-CN/640.ob-vector-search`，我们需要将这个目录下面所有的文档都上传。

![配置知识库](images/create-knowledge-base-2.png)

![配置知识库](images/create-knowledge-base-3.png)

![配置知识库](images/create-knowledge-base-4.png)

索引方式选择“高质量”，点击“保存并处理”。

![配置知识库](images/create-knowledge-base-5.png)

Dify 会提示知识库“已创建”，后续可能会看到某些文档已经在此处理完成。点击“前往文档”。

![配置知识库](images/create-knowledge-base-6.png)

![配置知识库](images/create-knowledge-base-7.png)

点击“前往文档”后会看到该知识库中的文档列表。

![配置知识库](images/create-knowledge-base-8.png)

### 4. 创建对话应用并选中知识库

点击“工作室”标签页，进入应用管理界面，点击“创建空白应用”。

![搭建 RAG 应用](images/create-application-1.png)

![搭建 RAG 应用](images/create-application-2.png)

保持默认选项“聊天助手”和“基础编排”即可，应用名称可以自行填写，例如 “OB 向量文档助手”。输入完成后点击“创建”按钮。

创建完成后会进入应用编排界面，首先关注右上角的默认模型设置，如果不是`qwen-turbo-2024-11-01`则修改为`qwen-turbo-2024-11-01`

![搭建 RAG 应用](images/create-knowledge-base-3.png)

点击“上下文”卡片中的“添加”按钮，选中刚才我们创建的知识库并点击“添加”按钮。

![搭建 RAG 应用](images/create-application-4.png)

![搭建 RAG 应用](images/create-application-5.png)

![搭建 RAG 应用](images/create-application-6.png)

随后，在提示词的输入框中填写如下的提示词：

```bash
你是一个专注于回答 OceanBase 社区版问题的机器人。
你的目标是利用可能存在的历史对话和检索到的文档片段，回答用户的问题。
任务描述：根据可能存在的历史对话、用户问题和检索到的文档片段，尝试回答用户问题。如果用户的问题与 OceanBase 无关，则抱歉说明无法回答。如果所有文档都无法解决用户问题，首先考虑用户问题的合理性。如果用户问题不合理，需要进行纠正。如果用户问题合理但找不到相关信息，则表示抱歉并给出基于内在知识的可能解答。如果文档中的信息可以解答用户问题，则根据文档信息严格回答问题。

回答要求：
- 如果所有文档都无法解决用户问题，首先考虑用户问题的合理性。如果用户问题不合理，请回答：“您的问题可能存在误解，实际上据我所知……（提供正确的信息）”。如果用户问题合理但找不到相关信息，请回答：“抱歉，无法从检索到的文档中找到解决此问题的信息。请联系OceanBase的人工答疑以获取更多帮助。基于我的内在知识，可能的解答是……（根据内在知识给出可能解答）”。
- 如果文档中的信息可以解答用户问题，请回答：“根据文档库中的信息，……（严格依据文档信息回答用户问题）”。如果答案可以在某一篇文档中找到，请在回答时直接指出依据的文档名称及段落的标题(不要指出片段标号)。
- 如果某个文档片段中包含代码，请务必引起重视，给用户的回答中尽可能包含代码。请完全参考文档信息回答用户问题，不要编造事实，尤其是数据表名、SQL 语句等关键信息。
- 如果需要综合多个文档中的片段信息，请全面地总结理解后尝试给出全面专业的回答。
- 尽可能分点并且详细地解答用户的问题，回答不宜过短。
```

![搭建 RAG 应用](images/create-application-7.png)

可以在右侧聊天框里进行应用调试，例如询问“请介绍一下 OceanBase 的向量功能”

![搭建 RAG 应用](images/create-application-8.png)

### 5. 发布应用，开始对话！

点击应用详情右上角的“发布”下面的“运行”按钮，会打开该应用的专属页面。

![发布应用](images/publish-the-application-1.png)

点击 Start Chat 按钮即可开始聊天。

![发布应用](images/publish-the-application-2.png)

如果你是在服务器上部署的 Dify，也可以将该应用的链接分享给身边的朋友，让他们也一起来试用一下吧！

自此，你已经通过 Dify + OceanBase 搭建了你自己的 LLM 应用平台和智能体应用，恭喜你！🎉
