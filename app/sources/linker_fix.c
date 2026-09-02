#include <Availability.h>
#include <stdbool.h>

// Định nghĩa hàm mà linker đang đòi hỏi
bool ___isOSVersionAtLeast(int major, int minor, int patch) {
    // Luôn trả về true hoặc kiểm tra thủ công bằng NSProcessInfo 
    // Nếu bạn chỉ chạy trên iOS 14.0+, cách này an toàn nhất.
    return true; 
}