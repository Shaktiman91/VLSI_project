def count_bytes_in_hex_file(filename: str) -> int:
    with open(filename, 'r') as file:
        hex_data = file.read()

    size_chars = hex_data.split("\n")[0]
    hex_data = hex_data.strip().replace('\n', '')[len(size_chars) + 1:].split(" ")
    return len(hex_data)

if __name__ == "__main__":
    import sys

    print(count_bytes_in_hex_file(sys.argv[1]))
