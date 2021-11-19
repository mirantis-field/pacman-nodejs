IMAGE_REPOSITORY = "pacman-nodejs"

// For available target clusters, contact your platform administrator
TARGET_CLUSTER_DOMAIN = "us.demo.mirantis.com"

// Available orchestrators = [ "kubernetes" | "swarm" ]
ORCHESTRATOR = "kubernetes"

// Available ingress = [ "ingress" | "istio_gateway" ]
KUBERNETES_INGRESS = "istio_gateway"

if(! CLUSTER.containsKey(TARGET_CLUSTER_DOMAIN)){
    error("Unknown cluster '${TARGET_CLUSTER_DOMAIN}'")
}
TARGET_CLUSTER = CLUSTER.get(TARGET_CLUSTER_DOMAIN)
// Changed for demo

if(ORCHESTRATOR.toLowerCase() == "kubernetes"){
    KUBERNETES_NAMESPACE_DEV = "${IMAGE_NAMESPACE_DEV}"
    KUBERNETES_NAMESPACE_PROD = "${IMAGE_NAMESPACE_PROD}"

    APPLICATION_DOMAIN = "${USERNAME}.${TARGET_CLUSTER['KUBE_DOMAIN_NAME']}"
}
else if (ORCHESTRATOR.toLowerCase() == "swarm"){
    SWARM_SERVICE_NAME = "${USERNAME}-${IMAGE_REPOSITORY}"
    SWARM_STACK_NAME = "${USERNAME}-${IMAGE_REPOSITORY}"
    UCP_COLLECTION_PATH = "/Shared/Private/${USERNAME}"

    APPLICATION_DOMAIN = "${USERNAME}.${TARGET_CLUSTER['SWARM_DOMAIN_NAME']}"
}
else {
    error("Unsupported orchestrator")
}

if(! ["ingress", "istio_gateway"].contains(KUBERNETES_INGRESS)){
    error("Unsupported Kubernetes ingress type '${KUBERNETES_INGRESS}'")
}

MONGO_TAG="latest"

node {
    def docker_image

    stage('Checkout') {
        checkout scm
    }

    stage('Build') {
        docker_image = docker.build("${IMAGE_NAMESPACE_DEV}/${IMAGE_REPOSITORY}")
    }

    stage('Unit Tests') {
        docker_image.inside {
            sh 'echo "Tests passed"'
        }
    }

    stage('Push') {
        docker.withRegistry(TARGET_CLUSTER['REGISTRY_URI'], TARGET_CLUSTER['REGISTRY_CREDENTIALS_ID']) {
            docker_image.push(IMAGE_TAG)
        }
    }

    stage('Scan') {
        httpRequest acceptType: 'APPLICATION_JSON', authentication: TARGET_CLUSTER['REGISTRY_CREDENTIALS_ID'], contentType: 'APPLICATION_JSON', httpMode: 'POST', ignoreSslErrors: true, responseHandle: 'NONE', url: "${TARGET_CLUSTER['REGISTRY_URI']}/api/v0/imagescan/scan/${IMAGE_NAMESPACE_DEV}/${IMAGE_REPOSITORY}/${IMAGE_TAG}/linux/amd64"

        def scan_result

        def scanning = true
        while(scanning) {
            def scan_result_response = httpRequest acceptType: 'APPLICATION_JSON', authentication: TARGET_CLUSTER['REGISTRY_CREDENTIALS_ID'], httpMode: 'GET', ignoreSslErrors: true, responseHandle: 'LEAVE_OPEN', url: "${TARGET_CLUSTER['REGISTRY_URI']}/api/v0/imagescan/scansummary/repositories/${IMAGE_NAMESPACE_DEV}/${IMAGE_REPOSITORY}/${IMAGE_TAG}"
            scan_result = readJSON text: scan_result_response.content

            if (scan_result.size() != 1) {
                println('Response: ' + scan_result)
                error('More than one imagescan returned, please narrow your search parameters')
            }

            scan_result = scan_result[0]

            if (!scan_result.check_completed_at.equals("0001-01-01T00:00:00Z")) {
                scanning = false
            } else {
                sleep 15
            }

        }
        println('Response JSON: ' + scan_result)
    }

    stage('Sign Development Image') {
        withEnv(["REGISTRY_HOSTNAME=${TARGET_CLUSTER['REGISTRY_HOSTNAME']}",
                 "IMAGE_NAMESPACE=${IMAGE_NAMESPACE_DEV}",
                 "IMAGE_REPOSITORY=${IMAGE_REPOSITORY}",
                 "IMAGE_TAG=${IMAGE_TAG}",
                 "TRUST_SIGNER_KEY=${TARGET_CLUSTER['TRUST_SIGNER_KEY']}"]) {
            withCredentials([string(credentialsId: TARGET_CLUSTER['TRUST_SIGNER_PASSPHRASE_CREDENTIALS_ID'] , variable: 'DOCKER_CONTENT_TRUST_REPOSITORY_PASSPHRASE')]) {
                sh 'docker trust key load ${TRUST_SIGNER_KEY}'
                sh 'docker trust sign ${REGISTRY_HOSTNAME}/${IMAGE_NAMESPACE}/${IMAGE_REPOSITORY}:${IMAGE_TAG}'
            }
        }
    }

    stage('Deploy to Development') {
        withEnv(["APPLICATION_FQDN=${IMAGE_REPOSITORY}.dev.${APPLICATION_DOMAIN}",
                 "REGISTRY_HOSTNAME=${TARGET_CLUSTER['REGISTRY_HOSTNAME']}",
                 "IMAGE_NAMESPACE=${IMAGE_NAMESPACE_DEV}",
                 "IMAGE_REPOSITORY=${IMAGE_REPOSITORY}",
                 "IMAGE_TAG=${IMAGE_TAG}",
                 "MONGO_TAG=${MONGO_TAG}",
                 "USERNAME=${USERNAME}"]) {
            if(ORCHESTRATOR.toLowerCase() == "kubernetes"){
                println("Deploying to Kubernetes")
                withEnv(["KUBERNETES_CONTEXT=${TARGET_CLUSTER['KUBERNETES_CONTEXT']}", 
                         "KUBERNETES_INGRESS=${KUBERNETES_INGRESS}",
                         "KUBERNETES_NAMESPACE=${KUBERNETES_NAMESPACE_DEV}"]) {
                    sh 'envsubst < kubernetes/cluster/001_mongo_pvc.yml | kubectl --context=${KUBERNETES_CONTEXT} --namespace=${KUBERNETES_NAMESPACE} apply -f -'
                    sh 'envsubst < kubernetes/cluster/002_mongo_deployment.yml | kubectl --context=${KUBERNETES_CONTEXT} --namespace=${KUBERNETES_NAMESPACE} apply -f -'
                    sh 'envsubst < kubernetes/cluster/003_mongo_service.yml | kubectl --context=${KUBERNETES_CONTEXT} --namespace=${KUBERNETES_NAMESPACE} apply -f -'
                    sh 'envsubst < kubernetes/cluster/004_pacman_deployment.yml | kubectl --context=${KUBERNETES_CONTEXT} --namespace=${KUBERNETES_NAMESPACE} apply -f -'
                    sh 'envsubst < kubernetes/cluster/005_pacman_service.yml | kubectl --context=${KUBERNETES_CONTEXT} --namespace=${KUBERNETES_NAMESPACE} apply -f -'
                    sh 'envsubst < kubernetes/cluster/006_pacman_${KUBERNETES_INGRESS}.yml | kubectl --context=${KUBERNETES_CONTEXT} --namespace=${KUBERNETES_NAMESPACE} apply -f -'
                }
            }
            else if (ORCHESTRATOR.toLowerCase() == "swarm"){
                println("Deploying to Swarm")
                withEnv(["UCP_COLLECTION_PATH=${UCP_COLLECTION_PATH}"]) {
                    withDockerServer([credentialsId: TARGET_CLUSTER['UCP_CREDENTIALS_ID'], uri: TARGET_CLUSTER['UCP_URI']]) {
                        sh "docker stack deploy -c swarm/docker-compose.yml ${SWARM_STACK_NAME}-dev"
                    }
                }
            }

            println("Application deployed to Development: http://${APPLICATION_FQDN}")
        }
    }

    stage('Integration Tests') {
        docker_image.inside {
            sh 'echo "Tests passed"'
        }
    }

    stage('Promote') {
        httpRequest acceptType: 'APPLICATION_JSON', authentication: TARGET_CLUSTER['REGISTRY_CREDENTIALS_ID'], contentType: 'APPLICATION_JSON', httpMode: 'POST', ignoreSslErrors: true, requestBody: "{\"targetRepository\": \"${IMAGE_NAMESPACE_PROD}/${IMAGE_REPOSITORY}\", \"targetTag\": \"${IMAGE_TAG}\"}", responseHandle: 'NONE', url: "${TARGET_CLUSTER['REGISTRY_URI']}/api/v0/repositories/${IMAGE_NAMESPACE_DEV}/${IMAGE_REPOSITORY}/tags/${IMAGE_TAG}/promotion"
    }

    stage('Sign Production Image') {
        withEnv(["REGISTRY_HOSTNAME=${TARGET_CLUSTER['REGISTRY_HOSTNAME']}",
                 "IMAGE_NAMESPACE=${IMAGE_NAMESPACE_PROD}",
                 "IMAGE_REPOSITORY=${IMAGE_REPOSITORY}",
                 "IMAGE_TAG=${IMAGE_TAG}",
                 "TRUST_SIGNER_KEY=${TARGET_CLUSTER['TRUST_SIGNER_KEY']}"]) {
            withCredentials([string(credentialsId: TARGET_CLUSTER['TRUST_SIGNER_PASSPHRASE_CREDENTIALS_ID'] , variable: 'DOCKER_CONTENT_TRUST_REPOSITORY_PASSPHRASE')]) {
                sh 'docker pull ${REGISTRY_HOSTNAME}/${IMAGE_NAMESPACE}/${IMAGE_REPOSITORY}:${IMAGE_TAG}'
                sh 'docker trust key load ${TRUST_SIGNER_KEY}'
                sh 'docker trust sign ${REGISTRY_HOSTNAME}/${IMAGE_NAMESPACE}/${IMAGE_REPOSITORY}:${IMAGE_TAG}'
            }
        }
    }

    stage('Deploy to Production') {
        withEnv(["APPLICATION_FQDN=${IMAGE_REPOSITORY}.prod.${APPLICATION_DOMAIN}",
                 "REGISTRY_HOSTNAME=${TARGET_CLUSTER['REGISTRY_HOSTNAME']}",
                 "IMAGE_NAMESPACE=${IMAGE_NAMESPACE_PROD}",
                 "IMAGE_REPOSITORY=${IMAGE_REPOSITORY}",
                 "IMAGE_TAG=${IMAGE_TAG}",
                 "MONGO_TAG=${MONGO_TAG}",
                 "USERNAME=${USERNAME}"]) {
            if(ORCHESTRATOR.toLowerCase() == "kubernetes"){
                println("Deploying to Kubernetes")
                withEnv(["KUBERNETES_CONTEXT=${TARGET_CLUSTER['KUBERNETES_CONTEXT']}", 
                         "KUBERNETES_INGRESS=${KUBERNETES_INGRESS}",
                         "KUBERNETES_NAMESPACE=${KUBERNETES_NAMESPACE_PROD}"]) {
                    sh 'envsubst < kubernetes/cluster/001_mongo_pvc.yml | kubectl --context=${KUBERNETES_CONTEXT} --namespace=${KUBERNETES_NAMESPACE} apply -f -'
                    sh 'envsubst < kubernetes/cluster/002_mongo_deployment.yml | kubectl --context=${KUBERNETES_CONTEXT} --namespace=${KUBERNETES_NAMESPACE} apply -f -'
                    sh 'envsubst < kubernetes/cluster/003_mongo_service.yml | kubectl --context=${KUBERNETES_CONTEXT} --namespace=${KUBERNETES_NAMESPACE} apply -f -'
                    sh 'envsubst < kubernetes/cluster/004_pacman_deployment.yml | kubectl --context=${KUBERNETES_CONTEXT} --namespace=${KUBERNETES_NAMESPACE} apply -f -'
                    sh 'envsubst < kubernetes/cluster/005_pacman_service.yml | kubectl --context=${KUBERNETES_CONTEXT} --namespace=${KUBERNETES_NAMESPACE} apply -f -'
                    sh 'envsubst < kubernetes/cluster/006_pacman_${KUBERNETES_INGRESS}.yml | kubectl --context=${KUBERNETES_CONTEXT} --namespace=${KUBERNETES_NAMESPACE} apply -f -'
                }
            }
            else if (ORCHESTRATOR.toLowerCase() == "swarm"){
                println("Deploying to Swarm")
                withEnv(["UCP_COLLECTION_PATH=${UCP_COLLECTION_PATH}"]) {
                    withDockerServer([credentialsId: TARGET_CLUSTER['UCP_CREDENTIALS_ID'], uri: TARGET_CLUSTER['UCP_URI']]) {
                        sh "docker stack deploy -c swarm/docker-compose.yml ${SWARM_STACK_NAME}"
                    }
                }
            }

            println("Application deployed to Production: http://${APPLICATION_FQDN}")
        }
    }
}
