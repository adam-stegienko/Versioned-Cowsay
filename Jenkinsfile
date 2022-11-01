pipeline {
    agent any
    environment {
        GITLAB = credentials('a31843c7-9aa6-4723-95ff-87a1feb934a1')
    }
    stages {
        stage('Setup parameters') {
            steps {
                script {
                    properties([
                        disableConcurrentBuilds(), 
                        gitLabConnection(gitLabConnection: 'GitLab API Connection', jobCredentialId: ''), 
                        [$class: 'GitlabLogoProperty', repositoryName: 'adam/cowsay'], 
                        parameters([
                            validatingString(
                                description: 'Put a 2-digit value meaning the branch you would like to build your version on, as in the following examples: "1.0", "1.1", "1.2", etc.', 
                                failedValidationMessage: 'Parameter format is not valid. Build aborted. Try again with valid parameter format.', 
                                name: 'Version', 
                                regex: '^[0-9]{1,}\\.[0-9]{1,}$'
                            )
                        ]), 
                    ])
                }
            }
        }
        stage('Non-release branch build') {
            when {
                allOf {
                    expression { env.GIT_BRANCH != "*/release*" }
                    expression { params.Version.isEmpty() }
                }
            }
            steps {
                script {
                    sh"""
                    git checkout main
                    git remote set-url origin http://\"$GITLAB\"@ec2-3-125-51-254.eu-central-1.compute.amazonaws.com/adam/cowsay.git
                    git pull origin main
                    docker build -t adam-cowsay:latest .
                    echo "Cowsay image has been built successfully."
                    aws ecr get-login-password --region eu-central-1 | docker login --username AWS --password-stdin 644435390668.dkr.ecr.eu-central-1.amazonaws.com
                    docker tag adam-cowsay:latest 644435390668.dkr.ecr.eu-central-1.amazonaws.com/adam-cowsay:latest
                    docker push 644435390668.dkr.ecr.eu-central-1.amazonaws.com/adam-cowsay:latest
                    echo "Cowsay image has been successfully pushed to remote repo."
                    """
                }
                echo "Latest image built and pushed for non-release branch."
            }
        }
        stage('Release branch existence validation') {
            when { not { expression { params.Version.isEmpty() } } }
            steps {
                script {
                    BRANCH = "release/$params.Version"
                    IMAGE_VERSION = params.Version
                    echo IMAGE_VERSION
                    sh"""
                    git checkout main
                    git remote set-url origin http://\"$GITLAB\"@ec2-3-125-51-254.eu-central-1.compute.amazonaws.com/adam/cowsay.git
                    git pull --rebase
                    """
                    BRANCH_EXISTING = sh(
                        script: "(git ls-remote -q | grep -w $BRANCH) || BRANCH_EXISTING=False",
                        returnStdout: true,
                    )
                    if (BRANCH_EXISTING) {
                        echo "The $BRANCH branch is already existing."
                        sh "git checkout $BRANCH && git pull --rebase"
                    } else {
                        echo "The $BRANCH branch is not exsiting yet and needs to be created."
                        sh """#!/bin/bash -xe
                        git branch $BRANCH
                        git checkout $BRANCH
                        git remote set-url origin http://\"$GITLAB\"@ec2-3-125-51-254.eu-central-1.compute.amazonaws.com/adam/cowsay.git
                        touch version.txt
                        printf "$IMAGE_VERSION\nNOT FOR RELEASE\n" > version.txt
                        git add .
                        git commit -m "[ci-skip] The $BRANCH branch created"
                        git tag $IMAGE_VERSION
                        git push origin --tags
                        git push -u origin $BRANCH
                        """
                        echo "The $BRANCH branch has been created."
                    }
                }
            }
        }
        stage('Version calculation') {
            when { not { expression { params.Version.isEmpty() } } }
            steps {
                script {
                    sh 'git fetch --tags'
                    TEMP_VERSION = sh(
                        script: "head -n1 ./version.txt",
                        returnStdout: true,
                    ).trim().toString()
                    echo TEMP_VERSION
                    if (!TEMP_VERSION.tokenize(".")[2]) {
                        LATEST_PATCH = "0"
                    } else {
                        LATEST_PATCH = (TEMP_VERSION.tokenize(".")[2].toInteger() + 1).toString()
                    }
                    echo LATEST_PATCH
                    env.NEW_VERSION = TEMP_VERSION.tokenize(".")[0] + "." + TEMP_VERSION.tokenize(".")[1] + "." + LATEST_PATCH
                    echo NEW_VERSION
                }
            }
        }
        stage('Image build') {
            when { not { expression { params.Version.isEmpty() } } }
            steps {
                script {
                    sh"""
                    docker build -t adam-cowsay:$NEW_VERSION .
                    """
                }
            }
        }
        stage('Push with latest release tag') {
            when { not { expression { params.Version.isEmpty() } } }
            steps {
                script {
                    sh"""#!/bin/bash -xe
                    printf \"$NEW_VERSION\nFOR RELEASE\n\" > version.txt
                    aws ecr get-login-password --region eu-central-1 | docker login --username AWS --password-stdin 644435390668.dkr.ecr.eu-central-1.amazonaws.com
                    docker tag adam-cowsay:$NEW_VERSION 644435390668.dkr.ecr.eu-central-1.amazonaws.com/adam-cowsay:$NEW_VERSION
                    docker push 644435390668.dkr.ecr.eu-central-1.amazonaws.com/adam-cowsay:$NEW_VERSION
                    docker tag adam-cowsay:$NEW_VERSION 644435390668.dkr.ecr.eu-central-1.amazonaws.com/adam-cowsay:latest
                    docker push 644435390668.dkr.ecr.eu-central-1.amazonaws.com/adam-cowsay:latest
                    git add .
                    git commit -am \"[ci-skip] New $NEW_VERSION version.\"
                    git tag $NEW_VERSION
                    git push origin --tags
                    git push origin $BRANCH
                    echo "Cowsay container has been built successfully."
                    """
                }
            }
        }
        stage('Pull, Run, and Test') {
            steps {
                script {
                    sh"""#!/bin/bash -xe
                    ssh -t -i "/home/.ssh/adam-lab.pem" ubuntu@18.192.58.176
                    aws ecr get-login-password --region eu-central-1 | docker login --username AWS --password-stdin 644435390668.dkr.ecr.eu-central-1.amazonaws.com
                    docker pull 644435390668.dkr.ecr.eu-central-1.amazonaws.com/adam-cowsay:latest
                    docker rm -f happy_cowsay
                    docker run --name=happy_cowsay -d -p 8000:8080 644435390668.dkr.ecr.eu-central-1.amazonaws.com/adam-cowsay:latest
                    sleep 8
                    curl http://18.192.58.176:8000
                    """
                }
            }
        }
    }
}  
