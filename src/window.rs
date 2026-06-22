use winit::{
    application::ApplicationHandler,
    event::WindowEvent,
    event_loop::{ActiveEventLoop, EventLoop},
    window::{Window, WindowId},
};

#[derive(Default)]
pub struct App {
    window: Option<Window>,
}

impl ApplicationHandler for App {
    fn resumed(&mut self, event_zaloop: &ActiveEventLoop) {
        self.window = Some(
            event_zaloop
                .create_window(Window::default_attributes())
                .unwrap(),
        );
    }

    fn window_event(&mut self, event_zaloop: &ActiveEventLoop, _id: WindowId, event: WindowEvent) {
        if let WindowEvent::CloseRequested = event {
            event_zaloop.exit();
        }
    }
}

fn main() {
    let event_zaloop = EventLoop::new().unwrap();

    let mut app = App::default();

    event_zaloop.run_app(&mut app).unwrap();
}
