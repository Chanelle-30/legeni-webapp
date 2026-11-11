// Pipeline de référence du TP 3.5 : tests -> build -> test d'acceptance -> push
pipeline {
    agent any

    parameters {
        string(name: 'DOCKERHUB_ID', defaultValue: 'legeni07', description: 'Votre identifiant Docker Hub')
        booleanParam(name: 'PUSH', defaultValue: true, description: "Pousser l'image sur Docker Hub")
    }

    environment {
        IMAGE          = "${params.DOCKERHUB_ID}/legeni-webapp"
        VERSION        = "1.0.${env.BUILD_NUMBER}"
        TEST_CONTAINER = "webapp-ci-${env.BUILD_NUMBER}"
        CI_NETWORK     = "ci-net-${env.BUILD_NUMBER}"
    }

    options {
        timestamps()
        timeout(time: 20, unit: 'MINUTES')
        buildDiscarder(logRotator(numToKeepStr: '10'))
    }

    stages {
        stage('Tests unitaires') {
            steps {
                // L'étape "test" du Dockerfile lance flake8 + pytest : si un test échoue, le build s'arrête ici
                sh 'docker build --target test -t legeni-webapp:test .'
            }
        }

        stage('Build image') {
            steps {
                sh 'docker build --build-arg APP_VERSION=$VERSION -t $IMAGE:$VERSION -t $IMAGE:latest .'
            }
        }

        stage("Test d'acceptance") {
            steps {
                sh '''
                    docker network create $CI_NETWORK
                    docker run -d --name $TEST_CONTAINER --network $CI_NETWORK $IMAGE:$VERSION
                    # On interroge le conteneur depuis un conteneur curl placé sur le même réseau
                    docker run --rm --network $CI_NETWORK curlimages/curl:8.11.1 \
                        -sf --retry 10 --retry-connrefused --retry-delay 1 http://$TEST_CONTAINER:5000/health
                    docker run --rm --network $CI_NETWORK curlimages/curl:8.11.1 \
                        -sf http://$TEST_CONTAINER:5000/ | grep -q "Version $VERSION"
                '''
            }
        }

        stage('Push Docker Hub') {
            when { expression { params.PUSH } }
            steps {
                withCredentials([usernamePassword(credentialsId: 'dockerhub',
                                                  usernameVariable: 'DH_USER',
                                                  passwordVariable: 'DH_TOKEN')]) {
                    sh '''
                        echo "$DH_TOKEN" | docker login -u "$DH_USER" --password-stdin
                        docker push $IMAGE:$VERSION
                        docker push $IMAGE:latest
                    '''
                }
            }
        }
    }

    post {
        always {
            sh 'docker rm -f $TEST_CONTAINER || true; docker network rm $CI_NETWORK || true'
        }
        success {
            echo "Image ${IMAGE}:${VERSION} construite et validée"
        }
        failure {
            echo "Échec du pipeline : consultez la console de l'étape en rouge"
        }
    }
}
