#[derive(thiserror::Error, Debug)]
pub enum Error {
    Todo, 
}

pub type Result<T> = std::result::Result<T, Error>;
