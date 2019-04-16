> ### Deleção do Cluster na AWS  


  **1º passo:** Delete do Cluster  
   
   - Acesse o Jenkins  
   
     1.1 - No campo de pesquisa, digite *Cluster* e clique em **cluster-delete**.   
   
       ![cluster-delete1](https://user-images.githubusercontent.com/7769947/38868203-a9ea59b0-421c-11e8-9720-cc0e131172e5.png)
   
     1.2 - Clique em **Run**
   
      ![cluster-delete2](https://user-images.githubusercontent.com/7769947/38868207-add99680-421c-11e8-95e2-e77012f942e2.png)
   
     1.3 - Selecione o cluster que deseja deletar.  
     
       ![cluster-delete3](https://user-images.githubusercontent.com/7769947/38868210-b0c48972-421c-11e8-98ea-1ec67ae822ed.png)

        - **INVOKE_DYNAMIC_PARAMETERS** - Se selecionado, irá carregar as stacks no momento da construção (execução), aqueles que             não estiverem disponiveis nas opções abaixo, os mesmos serão carregados de forma dinamica, conforme o passo-a-passo abaixo:
          
          **1º PASSO**: Na construção do carregamento de delete, o carregamento pausará em Deploy Parameters.  
          **2º PASSO**: Selecione a Stack existente que deseja deletar. 
          **3º PASSO**:  Clique em SET e prossiga. 
         
                        
          - Exemplo ilustrado:
            ![image](https://user-images.githubusercontent.com/11760799/38323964-404c6dba-3815-11e8-9696-c3d4def2db4f.png)
            
           - Deleção de cluster via Invoke Dynamic Parameters:
            ![image](https://user-images.githubusercontent.com/11760799/38367612-8f5ff27e-38b9-11e8-92ba-9867afc7044c.png)
          
        - **STACK** - Ao não selecionar o **INVOKE_DYNAMIC_PARAMETERS**, você terá que selecionar uma das opções no campo de seleção de
          Stacks. Caso não tenha a Stack desejada, retorne a etapa anterior. Caso tenha a Stack desejada, siga os passos abaixo:
        
          **1º PASSO**: Para essa opção, desmarque o botão de radio do: **INVOKE_DYNAMIC_PARAMETERS**.  
          **2º PASSO**: Selecione a Stack desejada na caixa de seleção do: **STACK**.  
          **3º PASSO**: Clique em construir.  
          **4º PASSO**: Aguarde o termino da Build de deleção do **Cluster**.  
        
           - Exemplo ilustrado:
            ![image](https://user-images.githubusercontent.com/11760799/38325333-0f75883a-3819-11e8-8a46-5293053baef6.png)
            
            - Deleção de cluster via construção pela caixa de seleção de Stack:
            ![image](https://user-images.githubusercontent.com/11760799/38325846-9441efa8-381a-11e8-8602-8a48b9713666.png)
        

  **2º passo:** Entendendo os estágios da deleção de Cluster.  

   - Estagios exibidos no Job de delete de cluster do Jenkins  
        **Update Slack**: Carrega o token de acesso ao Slack e executa as atualizações no canal especifico.  
         
        _Exemplo lógico:_  
         
      
           SLACK = new Slack()
           .withToken("xoxp-50850716951-200824430182-292471917479-7a2a1d676be42e690e53e7326dcc9ae9")
           .withChannel("#jenkins-ci")
           .withMask("Jenkins")

           SLACK.sendMessage("*STARTED:* Job _${JOB_NAME} [${BUILD_NUMBER}]_ (${BUILD_URL})")
            
        
        **Checkout SCM**: Verifica o gerenciamento de controle de script.  
         
        _Exemplo lógico:_  
         
            checkout scm
            
        
        **Deploy Parameters**: Define os parâmetros de escolha dinâmica.  
        
        _Exemplo lógico:_  
         
        
             // Define dynamic choice parameters
             VPC_NAMES = sh(script: "devops/jenkins/scripts/Parameter/getCloud9Vpcs.sh", returnStdout: true)
             INSTANCE_TYPES = sh(script: "devops/jenkins/scripts/Parameter/getInstancesTypes.sh", returnStdout: true)
             INSTANCE_KEYS = sh(script: "devops/jenkins/scripts/Parameter/getKeyPairs.sh", returnStdout: true)
             HOSTED_ZONES_NAMES = sh(script: "devops/jenkins/scripts/Parameter/getHostedZoneNames.sh", returnStdout: true)
             
             STATIC_PARAMETERS = 
              [
              booleanParam(name: 'INVOKE_DYNAMIC_PARAMETERS', description: 'Invoke Dynamic Parameters', defaultValue: true)
              ]
          
             DYNAMIC_PARAMETERS = 
              [
              choice(name: 'VPC_NAME', description: 'Vpc Name', choices: VPC_NAMES),
              string(name: 'FIRST_DEV_NAME', description: 'Instance Name', defaultValue: "devName"),
              choice(name: 'INSTANCE_TYPE', description: 'Instance Type', choices: INSTANCE_TYPES),
              choice(name: 'INSTANCE_KEY', description: 'Instance Key', choices: INSTANCE_KEYS),
              choice(name: 'HOSTED_ZONE_NAME', description: 'Hosted Zone Name', choices: HOSTED_ZONES_NAMES)
              ]
             
             STATIC_PARAMETERS += DYNAMIC_PARAMETERS
             properties([parameters(STATIC_PARAMETERS)]) 
             
              if (params.INVOKE_DYNAMIC_PARAMETERS)
               { 
               SLACK.sendMessage("*Attention!* Job _${JOB_NAME} [${BUILD_NUMBER}]_ (${BUILD_URL}) is paused and need input parameters!")
               params = input(message: 'Choose your variables!', ok: 'Set', parameters: DYNAMIC_PARAMETERS)
               }
              else
               {
                if (!VPC_NAMES.contains(params.VPC_NAME))
                 error("Invalid VPC_NAME!")
               
                if (!INSTANCE_TYPES.contains(params.INSTANCE_TYPE))
                 error("Invalid INSTANCE_TYPE!")
               
                if (!INSTANCE_KEYS.contains(params.INSTANCE_KEY))
                 error("Invalid INSTANCE_KEY!")
               
                if (!HOSTED_ZONES_NAMES.contains(params.HOSTED_ZONE_NAME))
                 error("Invalid HOSTED_ZONE_NAME!")
 
        **Define variables**: Define as variaveis do Cloudformation parameters.  
        
        _Exemplo lógico:_  
        
             //== Cloudformation parameters
             REGION = CLUSTER.tokenize(' : ')[0]
             CLUSTER_NAME = CLUSTER.tokenize(' : ')[1]
             STACK_NAME = "${CLUSTER_NAME}-cluster"
       
        **Delete Cloudformation**: Executa o comando de delete do Cluster, buscando por parametros a região e a stack do Cloudformation selecionada no inicio da Build.  
        
        _Exemplo lógico:_  
        
             CLOUDFORMATION_STAGE = true
             sh("aws cloudformation delete-stack --region ${REGION} --stack-name ${STACK_NAME}")
             sh("aws cloudformation wait stack-delete-complete --region ${REGION} --stack-name ${STACK_NAME}")
        

       
       -
            - Estagios do delete de Cluster. Exemplo ilustrativo:
            ![cluster-delete4](https://user-images.githubusercontent.com/7769947/38868215-b40d085c-421c-11e8-8ed7-17e5ced1e797.png)
