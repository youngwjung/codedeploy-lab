# AWS CodeDeploy

AWS CodeDeploy는 Amazon EC2, AWS Fargate, AWS Lambda 및 온프레미스 서버와 같은 다양한 컴퓨팅 서비스에 대한 소프트웨어 배포를 자동화하는 완전관리형 배포 서비스입니다. AWS CodeDeploy를 사용하면 새로운 기능을 더욱 쉽고 빠르게 출시할 수 있고, 애플리케이션을 배포하는 동안 가동 중지 시간을 줄이는 데 도움이 되며, 복잡한 애플리케이션 업데이트 작업을 처리할 수 있습니다. AWS CodeDeploy를 사용하여 소프트웨어 배포를 자동화함으로써 오류가 발생하기 쉬운 수동 작업을 제거할 수 있습니다.

## Lab Overview

1. Open Source Python Django Application을 수동으로 EC2에 배포
2. CloudFormation 템플릿을 이용해서 기본 인프라(VPC, ALB, 오토스케일링그룹, etc) 구성 및 배포
3. AWS CodePipeline & AWS CodeDeploy를 이용해서 애플리케이션 배포 자동화 구성

## 시작하기전에

1. 본 Hands-on lab에서 사용할 Application 예제는 MDN (the Mozilla Developer Network) 에서 만든 [튜토리얼](https://developer.mozilla.org/en-US/docs/Learn/Server-side/Django/Tutorial_local_library_website)의 예제입니다.
2. 본 Hands-on lab은 AWS Seoul region 기준으로 작성되었습니다. Region을 Seoul (ap-northeast-2)로 변경 후 진행 부탁드립니다.

## 수동으로 애플리케이션 배포

CI/CD 도구들을 사용해서 애플리케이션의 빌드, 테스트, 배포를 자동화하기전에 수동으로 배포해봄으로써 각 단계별로 필요한 명령어 및 실행순서를 정의합니다.

1. Amazon Linux 2 AMI를 이용해서 EC2 인스턴스를 생성
2. EC2 인스턴스에 SSH 접속
3. 리눅스 Root 유저로 전환

   ```bash
   sudo -i
   ```

4. Python3 및 Git 설치

   ```bash
   sudo yum install -y python3 git
   ```

5. 해당 [Git Repository](https://github.com/mdn/django-locallibrary-tutorial)를 Fork (GitHub 계정 필수)
6. Forking한 Repository를 Clone

   ```bash
   cd /opt && git clone https://<REPOSITORY_URL>
   ```

7. 파이썬 가상 환경 생성

   ```bash
   cd /opt/django-locallibrary-tutorial && python3 -m venv venv
   ```

8. 파이썬 가상 환경 활성화

   ```bash
   source venv/bin/activate
   ```

9. 애플리케이션 구동에 필요한 라이브러리 설치

   ```bash
   pip install -r requirements.txt
   ```

10. 해당 [문서](https://aws.amazon.com/getting-started/tutorials/create-connect-postgresql-db/)를 참고해서 RDS에서 Postgres 데이터베이스 인스턴스 생성

11. PostgreSQL 클라이언트 설치

    ```bash
    sudo yum install -y postgresql
    ```

12. RDS에 생성한 Postgres 인스턴스로 접속

    ```bash
    psql -h <RDS_ENDPOINT> -U <MASTER_USER>
    ```

13. 데이터베이스 및 데이터베이스 유저 생성

    ```sql
    CREATE DATABASE local_library;
    CREATE USER local_library WITH PASSWORD 'asdf1234';
    GRANT ALL PRIVILEGES ON DATABASE local_library TO local_library;
    ALTER USER local_library CREATEDB;
    ```

14. `locallibrary/settings.py` 파일을 열고 `ALLOWED_HOSTS`, `DATABASES`를 아래와 같이 수정

    ```python
    ALLOWED_HOSTS = ['*']

    ...
    ...

    DATABASES = {
        'default': {
            'ENGINE': 'django.db.backends.postgresql_psycopg2',
            'NAME': 'local_library',
            'USER': 'local_library',
            'PASSWORD': 'asdf1234',
            'HOST': '<RDS_ENDPOINT>',
            'PORT': '5432',
        }
    }
    ```

15. `locallibrary/settings.py` 파일을 열고 아래와 같은 코드블록을 삭제

    ```python
    # Heroku: Update database configuration from $DATABASE_URL.
    import dj_database_url
    db_from_env = dj_database_url.config(conn_max_age=500)
    DATABASES['default'].update(db_from_env)
    ```

16. django 애플리케이션 설정 및 테스트

    ```bash
    python manage.py makemigrations
    python manage.py migrate
    python manage.py collectstatic
    python manage.py test
    ```

17. django 애플리케이션을 구동 및 EC2 인스턴스의 퍼블릭 IP 주소로 접속 가능한지 확인

    ```bash
    python manage.py runserver 0.0.0.0:80
    ```

18. 아파치 웹서버 설치

    ```bash
    sudo yum install -y httpd
    ```

19. 아파치 mod_wsgi 모듈 설치

    ```bash
    sudo yum install -y httpd-devel gcc python3-devel
    pip install mod_wsgi
    ```

20. mod_wsgi 모듈 경로 확인

    ```bash
    mod_wsgi-express module-config
    ```

21. 아파치 웹서버 설정파일을 `/etc/httpd/conf.d/app.conf` 생성하고 아래와 같이 수정

    ```bash
    LoadModule wsgi_module "/opt/django-locallibrary-tutorial/venv/lib64/python3.7/site-packages/mod_wsgi/server/mod_wsgi-py37.cpython-37m-x86_64-linux-gnu.so"
    WSGIPythonHome "/opt/django-locallibrary-tutorial/venv"

    <Directory /opt/django-locallibrary-tutorial/locallibrary>
        Require all granted
    </Directory>

    WSGIDaemonProcess locallibrary python-path=/opt/django-locallibrary-tutorial:/opt/django-locallibrary-tutorial/venv/lib/python3.7/site-packages
    WSGIProcessGroup locallibrary
    WSGIScriptAlias / /opt/django-locallibrary-tutorial/locallibrary/wsgi.py
    ```

22. 아파치 웹서버에 애플리케이션 파일 권한 부여

    ```bash
    sudo chown -R apache:apache /opt/django-locallibrary-tutorial
    ```

23. 아파치 웹 서버 구동 및 EC2 인스턴스의 퍼블릭 IP 주소로 접속 가능한지 확인

    ```bash
    sudo systemctl enable httpd
    sudo systemctl start httpd
    ```

24. `/etc/httpd/conf.d/app.conf` 파일은 `/opt/django-locallibrary-tutorial` 디렉토리로 복사하고 애플리케이션 소스코드 변경 사항을 Git 리포지토리에 반영

    ```bash
    cp /etc/httpd/conf.d/app.conf /opt/django-locallibrary-tutorial
    cd /opt/django-locallibrary-tutorial
    git add .
    git commit -m "update django settings and add apache config"
    git push
    ```

## CloudFormation 템플릿으로 기본 인프라 구성

1. 해당 리포지토리에 있는 `base.yaml`를 다운로드
2. AWS Management Console 좌측 상단에 있는 **[Services]** 를 선택하고 검색창에서 CloudFormation을 검색하거나 Management & Governance 밑에 있는 **[CloudFormation]** 를 선택
3. CloudFormation을 Dashboard에서 **[Create stack]** 클릭후,**Prepare template** = Template is ready,\
   **Template source** = Upload a template file,\
   **Choose file** = base.yml,\
   **[Next]** 클릭
4. **Stack name** = base-infra, **[Next]** 클릭
5. **[Next]** &rightarrow; :white_check_mark: I acknowledge that AWS CloudFormation might create IAM resources. &rightarrow; **[Create Stack]**
6. 스택 생성 완료 후 **Outputs**에 나온 ALBEndpoint로 접속해서 인프라 구성 완료 여부 확인
7. AWS Systems Manager Session Manager를 통해서 EC2 인스턴스에 접속
8. Postgres 인스턴스로 접속 (**Outputs**에서 RDSEndpoint 확인 가능)

   ```bash
   PGPASSWORD=asdf1234 psql -h <RDS_ENDPOINT> -U postgres
   ```

9. 데이터베이스 및 데이터베이스 유저 생성

   ```sql
   CREATE DATABASE local_library;
   CREATE USER local_library WITH PASSWORD 'asdf1234';
   GRANT ALL PRIVILEGES ON DATABASE local_library TO local_library;
   ALTER USER local_library CREATEDB;
   ```

## AWS CodeDeploy 배포 구성

1. 해당 [링크](https://docs.aws.amazon.com/codedeploy/latest/userguide/getting-started-create-service-role.html)를 참고해서 CodeDeploy 서비스 역할을 생성하세요.

2. AWS Management Console에서 좌측 상단에 있는 **[Services]** 를 선택하고 검색창에서 CodeDeploy를 검색하거나 **[Developer Tools]** 밑에 있는 **[CodeDeploy]** 를 선택
3. **[Create application]** &rightarrow; **Application name** = library, **Compute platform** = EC2/On-premises &rightarrow; **[Create application]**
4. **[Create deployment group]** &rightarrow; **Deployment group name** = EC2-ASG, \
   **Service role** = 위에서 생성한 IAM 역할, \
   **Deployment type** = In-place, \
   **Environment configuration** = Amazon EC2 Auto Scaling groups, \
   Dropdown 목록에서 오토스케일링 그룹 선택, \
   **Load balancer** = Dropdown 목록에서 대상그룹 선택, \
   **[Create deployment group]**
5. 해당 리포지토리에 있는 `scripts` 디렉토리와 `appspec.yaml` 파일을 애플리케이션 소스코드가 있는 디렉토리로 복사하고 변경분을 리포지토리에 반영

## AWS CodePipeline 배포 자동화 구성

1. AWS Management Console에서 좌측 상단에 있는 **[Services]** 를 선택하고 검색창에서 CodePipeline를 검색하거나 **[Developer Tools]** 밑에 있는 **[CodePipeline]** 를 선택
2. **[Create pipeline]** &rightarrow; **Pipeline name** = library, **Service role** = New service role &rightarrow; **[Next]** &rightarrow; **Source provider** = GitHub &rightarrow; **[Connect to GitHub]** &rightarrow; **Repository** = 랩 시작할때 Forking한 Repository, **Branch** = master &rightarrow; **[Next]** &rightarrow; **[Skip build stage]**
3. **Deploy provider** = AWS CodeDeploy, **Region** = Asia Pacific (Seoul), \
   **Application name** = library, **Deployment group** = EC2-ASG \
   &rightarrow; **[Next]** &rightarrow; **[Create pipeline]**
4. 배포 파이프라인 생성 후 자동으로 배포가 실행되지만 CodeDeploy에서 에러 발생
5. 코드를 수정하고 리포지토리에 반영 후 배포가 완료되는지 확인하고 계속 에러 발생시 로그를 확인해서 코드 수정
6. `catalog/templates/index.html` 파일을 수정하고 리포지토리에 반영 후 변경사항이 정상적으로 배포 되는지 확인
7. 오토스케일링 그룹의 최소 인스턴스 갯수를 2로 수정하고 새로운 인스턴스에 애플리케이션이 정상적으로 배포되는지 확인

## Cleanup

1. CodePipeline 삭제
2. CodeDeploy 삭제
3. CloudFormation 스택 삭제
