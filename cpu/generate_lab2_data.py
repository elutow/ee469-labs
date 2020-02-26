with open('lab2_data.hex', 'w') as f:
    for i in range(16):
        result = 0
        for j in range(4):
            result += (4*i+j) << (8*(3-j))
        f.write(f'{result:0{8}x}\n')
