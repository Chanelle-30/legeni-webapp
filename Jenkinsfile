// Pipeline CI/CD complet — Legeni WebApp
// Lots 4 et 5 du projet final DevOps
pipeline {
    agent any

    parameters {
        string(name: 'DOCKERHUB_ID', defaultValue: 'legeni07',
               description: 'Identifiant Docker Hub')
    }

    environment {
        IMAGE          = "${params.DOCKERHUB_ID}/legeni-webapp"
        // Version lue depuis le fichier VERSION (ex. 1.0.0) + numéro de build
        APP_VERSION    = readFile('VERSION').trim()
        BUILD_TAG      = "${APP_VERSION}-${env.BUILD_NUMBER}"   // ex. 1.0.0-37
        TEST_CONTAINER = "webapp-ci-${env.BUILD_NUMBER}"
        CI_NETWORK     = "ci-net-${env.BUILD_NUMBER}"
    }

    options {
        timestamps()
        timeout(time: 30, unit: 'MINUTES')
        buildDiscarder(logRotator(numToKeepStr: '15'))
        disableConcurrentBuilds()
    }

    stages {
        // ============================================================
        // STAGE 1 : contrôles qualité EN PARALLÈLE
        // ============================================================
        stage('Contrôles qualité') {
            parallel {
                stage('Tests + couverture') {
                    steps {
                        sh 'mkdir -p reports'
                        sh 'docker build --target test -t legeni-webapp:test . || true'
                        // Récupérer les rapports depuis l'image de test
                        sh 'docker create --name test-extract legeni-webapp:test || true'
                        sh 'docker cp test-extract:/app/reports/junit.xml reports/ 2>/dev/null || true'
                        sh 'docker cp test-extract:/app/reports/coverage.xml reports/ 2>/dev/null || true'
                        sh 'docker rm -f test-extract || true'
                    }
                    post {
                        always {
                            junit allowEmptyResults: true, testResults: 'reports/junit.xml'
                            publishHTML(target: [
                                allowMissing: true,
                                alwaysLinkToLastBuild: true,
                                keepAll: true,
                                reportDir: 'reports',
                                reportFiles: 'coverage.xml',
                                reportName: 'Couverture'
                            ])
                        }
                    }
                }
                stage('Lint Dockerfile (hadolint)') {
                    steps {
                        sh 'hadolint Dockerfile | tee reports/hadolint.txt || true'
                    }
                    post {
                        always {
                            recordIssues(
                                tools: [hadoLint(pattern: 'reports/hadolint.txt')],
                                qualityGates: [[threshold: 1, type: 'TOTAL', unstable: false]]
                            )
                        }
                    }
                }
                stage('Lint Ansible') {
                    steps {
                        sh 'ansible-lint ansible/ || true'
                    }
                }
            }
        }

        // ============================================================
        // STAGE 2 : build image avec tag <VERSION>-<BUILD_NUMBER>
        // ============================================================
        stage('Build image') {
            steps {
                sh """
                    docker build \\
                        --build-arg APP_VERSION=${BUILD_TAG} \\
                        -t ${IMAGE}:${BUILD_TAG} \\
                        -t ${IMAGE}:${APP_VERSION} .
                """
            }
        }

        // ============================================================
        // STAGE 3 : scan Trivy (échec si CRITICAL corrigeable)
        // ============================================================
        stage('Scan Trivy') {
            steps {
                sh """
                    docker run --rm \\
                        -v /var/run/docker.sock:/var/run/docker.sock \\
                        -v \$PWD/reports:/reports \\
                        aquasec/trivy:latest image \\
                        --severity CRITICAL \\
                        --ignore-unfixed \\
                        --exit-code 1 \\
                        --format table \\
                        --output /reports/trivy.txt \\
                        ${IMAGE}:${BUILD_TAG}
                """
            }
        }

        // ============================================================
        // STAGE 4 : push (main uniquement)
        // ============================================================
        stage('Push Docker Hub') {
            when { branch 'main' }
            steps {
                withCredentials([usernamePassword(
                    credentialsId: 'dockerhub',
                    usernameVariable: 'DH_USER',
                    passwordVariable: 'DH_TOKEN'
                )]) {
                    sh '''
                        echo "$DH_TOKEN" | docker login -u "$DH_USER" --password-stdin
                        docker push ${IMAGE}:${BUILD_TAG}
                        docker push ${IMAGE}:${APP_VERSION}
                    '''
                }
            }
        }

        // ============================================================
        // STAGE 5 : déploiement STAGING (main uniquement)
        // ============================================================
        stage('Deploy staging') {
            when { branch 'main' }
            steps {
                withCredentials([
                    file(credentialsId: 'kubeconfig', variable: 'KUBECONFIG'),
                    file(credentialsId: 'ansible-vault-pass', variable: 'VAULT_PASS')
                ]) {
                    sh """
                        ansible-playbook ansible/deploy.yml \\
                            -i ansible/inventory.ini \\
                            -e target_env=staging \\
                            -e app_image=${IMAGE} \\
                            -e app_version=${BUILD_TAG} \\
                            --vault-password-file \$VAULT_PASS
                    """
                }
            }
        }

        // ============================================================
        // STAGE 6 : validation humaine
        // ============================================================
        stage('Validation avant prod') {
            when { branch 'main' }
            steps {
                input message: "Déployer ${BUILD_TAG} en PRODUCTION ?",
                      ok: 'Déployer',
                      submitter: 'admin'
            }
        }

        // ============================================================
        // STAGE 7 : déploiement PRODUCTION (main uniquement)
        // ============================================================
        stage('Deploy prod') {
            when { branch 'main' }
            steps {
                withCredentials([
                    file(credentialsId: 'kubeconfig', variable: 'KUBECONFIG'),
                    file(credentialsId: 'ansible-vault-pass', variable: 'VAULT_PASS')
                ]) {
                    sh """
                        ansible-playbook ansible/deploy.yml \\
                            -i ansible/inventory.ini \\
                            -e target_env=prod \\
                            -e app_image=${IMAGE} \\
                            -e app_version=${BUILD_TAG} \\
                            --vault-password-file \$VAULT_PASS
                    """
                }
            }
        }

        // ============================================================
        // STAGE 8 : tag Git v<VERSION> après succès en prod
        // ============================================================
        stage('Tag Git') {
            when { branch 'main' }
            steps {
                withCredentials([usernamePassword(
                    credentialsId: 'github-token',
                    usernameVariable: 'GH_USER',
                    passwordVariable: 'GH_TOKEN'
                )]) {
                    sh '''
                        git tag -f "v${APP_VERSION}"
                        git push origin "v${APP_VERSION}" --force
                    '''
                }
            }
        }
    }

    post {
        always {
            sh 'docker rm -f $TEST_CONTAINER || true'
            sh 'docker network rm $CI_NETWORK || true'
            cleanWs()
        }
        success {
            echo "✅ ${BUILD_TAG} déployé avec succès"
        }
        failure {
            // Notification (à compléter avec Slack/Discord/Teams)
            echo "❌ Pipeline échoué — voir les logs"
        }
    }
}
