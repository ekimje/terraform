# 트러블슈팅 실습

실무에서 자주 일어나는 장애를 Linux EC2(`linux-ec2`)에 일부러 만들어 두고, 증상만 보고 원인을 찾아 고치는 실습입니다.

## 진행 방법
1. 장애가 발생한 시나리오 문서를 열고 **상황과 증상**만 읽습니다.
2. 서버에 접속해서 원인을 찾고 고칩니다.
   ```cmd
   cd %USERPROFILE%\Desktop
   ssh -i linux.pem ec2-user@<linux_public_ip>
   ```
   `terraform destroy` 후 다시 `apply`하면 IP가 바뀝니다. 현재 IP는 `terraform output linux_public_ip`로 확인하세요. 각 시나리오 문서에는 실습 당시의 IP가 적혀 있습니다.
3. 막히면 문서의 힌트를 **1단계씩** 펼쳐 봅니다.
4. 해결했으면 문서 맨 아래 **해결 기록**을 채웁니다. 실무의 장애 보고서(포스트모템) 연습입니다.
5. 해결 확인이 끝나면 다음 시나리오로 넘어갑니다.

## 시나리오

| # | 시나리오 | 상태 |
|---|---|---|
| 1 | [디스크 가득 참](01-disk-full.md) | 🟢 해결 |
| 2 | [설정 파일 문법 오류](02-config-syntax.md) | 🟢 해결 |
| 3 | [권한 문제 (403 Forbidden)](03-permission.md) | 🟢 해결 |
| 4 | [포트 충돌](04-port-conflict.md) | 🟢 해결 |
| 5 | [접속 불가 (네트워크 vs 서비스)](05-network.md) | 🟢 해결 |
| 6 | 재부팅 후 서비스 미기동 | ⏳ 대기 |
