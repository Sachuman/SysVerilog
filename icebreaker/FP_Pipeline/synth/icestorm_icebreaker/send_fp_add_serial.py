
import argparse
import struct
import serial

if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Send two float32s over serial (big-endian), read back a float32 result"
    )
    parser.add_argument("port", help="Serial port device, e.g. /dev/ttyUSB1")
    parser.add_argument("baud", type=int, help="Baud rate, e.g. 9600")
    parser.add_argument("a", type=float, help="First float32 value to send")
    parser.add_argument("b", type=float, help="Second float32 value to send")
    args = parser.parse_args()

    ser = serial.Serial(
        port=args.port,
        baudrate=args.baud,
        bytesize=serial.EIGHTBITS,
        parity=serial.PARITY_NONE,
        stopbits=serial.STOPBITS_ONE,
        timeout=1
    )

    ser.reset_input_buffer()

    data = struct.pack(">f", args.a) + struct.pack(">f", args.b)
    ser.write(data)

    result_bytes = ser.read(4)
    if len(result_bytes) != 4:
        print(f"Expected 4 bytes, got {len(result_bytes)} bytes")
    else:
        result = struct.unpack(">f", result_bytes)[0]
        print(f"Received result: {result}")

    ser.close()
