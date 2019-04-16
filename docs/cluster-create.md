> ### Criação do Cluster na AWS  


  **1º passo:** Criação do Cluster  
   
   - Acesse o Jenkins 
     1.1 - No campo de pesquisa, digite *Cluster* e clique em **cluster-deploy**.  
   
       ![cluster-deploy1](https://user-images.githubusercontent.com/7769947/38867300-fdc6eba0-4219-11e8-8551-e3ff6f32e147.png)
   
     1.2 - Clique em **Run**
   
       ![cluster-deploy2](https://user-images.githubusercontent.com/7769947/38867305-0372837a-421a-11e8-8a6d-61e621febaa3.png)
   
     1.3 - Preencha os Campos  

        - **INVOKE_DYNAMIC_PARAMETERS** - Se selecionado, irá carregar os parâmetros no momento da construção (execução), aqueles que             não estiverem disponiveis nas opções abaixo, os mesmos serão carregados de forma dinamica, conforme a ilustração abaixo:
          
          - Exemplo:
            ![image](https://user-images.githubusercontent.com/11760799/38251322-833dfda8-3727-11e8-80d5-21ba376c7e7a.png)
          
                  
        - **REGION**: Escolha a Região do seu Cluster.
        - **CLUSTER_NAME**: Dê um nome para o seu Cluster.
        - **CLUSTER_TYPE**: Selecione o Tipo de instância para o seu Cluster. Ex.: *t2.micro*
        - **CLUSTER_KEY**: Selecione uma chave já existente para a criação da sua instância ECS.
        - **CLUSTER_MIN_MACHINES**: Insira o número mínimo de instâncias que permaneceram ativas simultâneamente
        - **CLUSTER_MAX_MACHINES**: Insira o número máximo de instâncias a serem escalonadas.
        - **CLUSTER_CERTIFICATE**: Selecione o certiicado de domínio para o seu Cluster.
        - **DB_ENCRYPTION_KEY**: Selecione a chave de encriptação do seu banco de dados.
        - **DB_SNAPSHOT**: Selecione se deseja que seja criado um snapshot do banco de dado, caso sim, escolha a regição. Padrão:                 without.
        - **DB_ENGINE_VERSION**: Selecione a versão da engine do seu banco de dados.	
        - **DB_TYPE**: Selecione o tipo de instância de banco de dados deseja criar. Ex.: *t2.small*.
        - **DB_STORAGE_TYPE**: Selecione o tipo de armazenamento deseja criar. Ex.: Standard.
        - **DB_SIZE**: Insira o tamanho do banco de dados em GB que deseja criar. Ex.: 30.
        - **DB_HAS_MULTIAZ**: Selecione se deseja que seu banco de dados seja replicado em várias regiões.
        - **DB_HAS_AUTOMATIC_BACKU**: Selecione se deseja que o backup do seu banco de dados seja feito de forma automática.
        -	**CREATE_PUBLIC_ALB**: Selecione se deseja criar LOAD BALANCE para o seu cluster.
        - **TYPE_API_GATEWAY**: Selecione o tipo de gateway, AWS_PROXY, HTTP_PROXY ou sem gateway de api.
        - **LAMBDA_API_GATEWAY_PROXY**: Selecione *without* para não usar gateway lambda ou A função lambda disponível, caso o                     **TYPE_API_GATEWAY** for **AWS_PROXY**.
        - **LAMBDA_API_GATEWAY_AUTHORIZER**: Selecione a função lambda que fará o tratamento de autorização das requisições. Essa opção           só é valida se o **TYPE_API_GATEWAY** for **AWS_PROXY** ou **HTTP_PROXY**.
        - **LAMBDA_ALARM_TO_SLACK**: Selecione o Alarme para receber notificações na integração com o Slack.
              
   - Após realizar as configurações clique em **Run**  
   
   
   ![cluster-deploy3](https://user-images.githubusercontent.com/7769947/38867307-06cae1ac-421a-11e8-84c6-04fb26c5294c.png)
   
   - As imagens a seguir mostram respectivamente o pipeline do Cluster, a criação das stacks no cloudformation e do cluster na ecs.  
   
   
  > ### Pipeline Jenkis  
  
  ![cluster-deploy4](https://user-images.githubusercontent.com/7769947/38867314-0e41c23e-421a-11e8-8170-0778536d77ab.png)
  
  - #### Entendendo os estágios de criação do Cluster.  
  
  
  - Neste momento temos as seguintes etapas sendo automatizadas pelo Jenkins:  
  
      - **Update Slack**: É feito o carregamento do token de acesso ao Slack, dispara uma notificação no canal do Slack informando o              inicio do build do pipeline.  
      
          _Exemplo lógico:_  
          
             //== Slack parameters
             SLACK = new Slack()
             .withToken("xoxp-50850716951-200824430182-292471917479-7a2a1d676be42e690e53e7326dcc9ae9")
             .withChannel("#jenkins-ci")
             .withMask("Jenkins")

              SLACK.sendMessage("*STARTED:* Job _${JOB_NAME} [${BUILD_NUMBER}]_ (${BUILD_URL})")
             
          
      
      - **Checkout SCM**: É feito um fetch dos arquivos contido no repositório de versionamento local ou remoto através do GIT.  
      
         _Exemplo lógico:_  
         
               checkout scm
               
      
      - **Deploy Parameters**: Os parametros definidos anteriormente são carregados de forma dinâmica ou pré-definida.  
      
         _Exemplo lógico:_  
         
      
                 // Define dynamic choice parameters
                REGIONS = sh(script: "devops/jenkins/scripts/Parameter/getRegions.sh", returnStdout: true).trim()
                CLUSTER_TYPES= sh(script: "devops/jenkins/scripts/Parameter/getInstancesTypes.sh", returnStdout: true).trim()
                CLUSTER_KEYS = sh(script: "devops/jenkins/scripts/Parameter/getKeyPairs.sh", returnStdout: true).trim()
                CLUSTER_CERTIFICATES = sh(script: "devops/jenkins/scripts/Parameter/getCertificates.sh", returnStdout: true).trim()
                DB_ENCRYPTION_KEYS = sh(script: "devops/jenkins/scripts/Parameter/getKmsKeys.sh", returnStdout: true).trim()
                DB_SNAPSHOTS = sh(script: "devops/jenkins/scripts/Parameter/getDbSnapshots.sh", returnStdout: true).trim()
                DB_ENGINE_VERSIONS = sh(script: "devops/jenkins/scripts/Parameter/getDbEngineVersions.sh", returnStdout:                                true).trim()
                DB_TYPES = sh(script: "devops/jenkins/scripts/Parameter/getDbTypes.sh", returnStdout: true).trim()
                LAMBDA_ALARMS_TO_SLACK = sh(script: "devops/jenkins/scripts/Parameter/getLambdaArnsByType.sh AlarmToSlack",                              returnStdout: true).trim()
                LAMBDA_API_GATEWAY_AUTHORIZERS = sh(script: "devops/jenkins/scripts/Parameter/getLambdaArnsByType.sh                                    ApiGatewayAuthorizer", returnStdout: true).trim()
                LAMBDA_API_GATEWAY_PROXYS = sh(script: "devops/jenkins/scripts/Parameter/getLambdaArnsByType.sh ApiGatewayProxy",                        returnStdout: true).trim()
             
      
      - **Define Variables**: Os parâmetros gerais são definidos para todos os serviços que serão criados, S3, CLoudFormation, RDS e              etc.  
      
         _Exemplo lógico:_  
         
             
                 //== General parameters
                 LOCAL_IMAGE_NAME = "reverse-proxy"
                 STACK_NAME = "${params.CLUSTER_NAME}-cluster"
                 IMAGE_VERSION = System.currentTimeMillis()
                   
         
      - **Validate CloudFormation**: Os parâmetros definidos anteriormente são validados no template do CloudFormation.
         _Exemplo lógico:_  
         
            sh("aws cloudformation --region ${params.REGION} validate-template --template-url                                                       https://s3.amazonaws.com/${S3_BUCKET}/cloudformation/${TYPE_PROJECT}/*.yml")
               
         
      - **Copy Scripts to S3**: Os arquivos são sincronizado com o bucket S3 que será criado.  
      
         _Exemplo lógico:_  
         
             sh("aws s3 sync devops/cloudformation s3://${S3_BUCKET}/cloudformation/${TYPE_PROJECT}/")
             
         
      - **Deploy CloudFormation**: É iniciado a criação de todos os stacks necessarios no Cloudformation:  
        - É feito uma chamda pelo aws cli para deploy do cloudformation.  
        - Todos os parametros definidos no template do cloudformation são carregados.  
        
        _Exemplo lógico:_  
       

                      sh("aws cloudformation deploy --region ${params.REGION} --stack-name lambda-${LAMBDA_API_GATEWAY_PROXY_NAME} -
                      capabilities CAPABILITY_NAMED_IAM --no-fail-on-empty-changeset --template-file devops/cloudformation/lambda.yml -
                      parameter-overrides InternalAccessSecurityGroup=" + Utilities.getCloudFormationVariable(params.REGION,
                      "${params.CLUSTER_NAME}InternalAccessSecurityGroup") + " PrivateSubnet1=" +
                      Utilities.getCloudFormationVariable(params.REGION, "${params.CLUSTER_NAME}PrivateSubnet1") + " PrivateSubnet2=" +
                      Utilities.getCloudFormationVariable(params.REGION, "${params.CLUSTER_NAME}PrivateSubnet2"))
                    
        
      - **Create Schema**: O script de criação do banco de dados é carregado e executado pelo job do Jenkins através de uma chamada             bash.  
         _Exemplo lógico:_  
         
            sh("devops/jenkins/scripts/MySQL/query.sh ${params.REGION} ${params.CLUSTER_NAME} \"CREATE DATABASE IF NOT EXISTS
            ${CLUSTER_NAME}\"")
         
  
  > ### Stacks CloudFormation  
  
  ![cluster-deploy1-cloudform](https://user-images.githubusercontent.com/7769947/38365077-54fc5de6-38b1-11e8-9cf7-254aec68c1a5.png)  
  
  > ### ECS  
  
  ![cluster-deploy1-ecs](https://user-images.githubusercontent.com/7769947/38365152-9dab36e8-38b1-11e8-8350-6911695c4856.png)
  
  
  
  Se não ocorreram erros durante o processo, o seu cluster foi criado com sucesso.  
  
  ![cluster-deploy9](https://user-images.githubusercontent.com/7769947/38869779-28702c7e-4222-11e8-8a3f-585909313968.png)

