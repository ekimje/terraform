# 리소스 이름 변경 시 기존 리소스를 삭제/재생성하지 않고 state 주소만 옮김
moved {
  from = aws_subnet.subnet1
  to   = aws_subnet.public_subnet1
}

moved {
  from = aws_subnet.subnet2
  to   = aws_subnet.public_subnet2
}
