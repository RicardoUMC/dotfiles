#include <wayland-server-core.h>

#include <cerrno>
#include <cctype>
#include <cstddef>
#include <cstdlib>
#include <iostream>
#include <string>
#include <string_view>
#include <unistd.h>

namespace {

constexpr int kDefaultDeadlineMs = 1000;
constexpr std::size_t kMaxSocketNameLength = 107;

struct LifecycleState {
    wl_display* display = nullptr;
    bool terminated = false;
};

bool valid_socket_name(std::string_view name)
{
    if (name.empty() || name == "." || name == ".." || name.size() > kMaxSocketNameLength) {
        return false;
    }

    for (const unsigned char character : name) {
        if (!(std::isalnum(character) || character == '_' || character == '-')) {
            return false;
        }
    }
    return true;
}

bool parse_deadline(std::string_view value, int& deadline_ms)
{
    if (value.empty()) {
        return false;
    }

    for (const unsigned char character : value) {
        if (!std::isdigit(character)) {
            return false;
        }
    }

    errno = 0;
    char* end = nullptr;
    const std::string owned_value(value);
    const long parsed = std::strtol(owned_value.c_str(), &end, 10);
    if (errno != 0 || end == owned_value.c_str() || *end != '\0' || parsed < 1 || parsed > 60000) {
        return false;
    }

    deadline_ms = static_cast<int>(parsed);
    return true;
}

void print_usage(const char* program)
{
    std::cerr << "usage: " << program << " --socket NAME [--deadline-ms N]\n";
}

int timer_callback(void* data)
{
    auto* state = static_cast<LifecycleState*>(data);
    state->terminated = true;
    wl_display_terminate(state->display);
    return 0;
}

} // namespace

int main(int argc, char** argv)
{
    std::string socket_name;
    int deadline_ms = kDefaultDeadlineMs;

    for (int index = 1; index < argc; ++index) {
        const std::string_view argument(argv[index]);
        if (argument == "--socket" && index + 1 < argc) {
            socket_name = argv[++index];
        } else if (argument == "--deadline-ms" && index + 1 < argc) {
            if (!parse_deadline(argv[++index], deadline_ms)) {
                std::cerr << "invalid --deadline-ms (expected 1..60000)\n";
                return 2;
            }
        } else {
            print_usage(argv[0]);
            return 2;
        }
    }

    if (!valid_socket_name(socket_name)) {
        std::cerr << "invalid or missing --socket (use an alphanumeric, '_' or '-' name)\n";
        return 2;
    }

    wl_display* display = wl_display_create();
    if (!display) {
        std::cerr << "wl_display_create failed\n";
        return 1;
    }

    if (wl_display_add_socket(display, socket_name.c_str()) != 0) {
        std::cerr << "wl_display_add_socket failed\n";
        wl_display_destroy_clients(display);
        wl_display_destroy(display);
        return 1;
    }

    LifecycleState state{display};
    wl_event_source* timer = wl_event_loop_add_timer(
        wl_display_get_event_loop(display), timer_callback, &state);
    if (!timer || wl_event_source_timer_update(timer, deadline_ms) != 0) {
        std::cerr << "timer setup failed\n";
        if (timer) {
            wl_event_source_remove(timer);
        }
        wl_display_destroy_clients(display);
        wl_display_destroy(display);
        return 1;
    }

    std::cout << "TOKYO_WAYLAND_SERVER_READY"
              << " pid=" << static_cast<long long>(getpid())
              << " socket=" << socket_name
              << " deadline_ms=" << deadline_ms << '\n';
    std::cout.flush();

    int result = 0;
    while (!state.terminated) {
        if (wl_event_loop_dispatch(wl_display_get_event_loop(display), -1) < 0) {
            result = 1;
            break;
        }
    }

    wl_display_destroy_clients(display);
    wl_display_destroy(display);
    return result;
}
