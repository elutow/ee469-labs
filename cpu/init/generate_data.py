with open('data.hex', 'w') as f:
    for i in range(256):
        result = 0
        for j in range(4):
            byte_value = i+j
            if byte_value >= 256:
                byte_value = 255 - (byte_value % 256)
            assert byte_value < 256
            assert byte_value >= 0
            result += byte_value << (8*(3-j))
        f.write(f'{result:0{8}x}\n')
