//! Validación de tx pendientes, orden por fee, constructor de plantilla de bloque
//!
//! Implementa: SPEC.md §<pendiente> — Fase 0, esqueleto sin lógica.

#![doc = include_str!("../README.md")]

pub mod tarifa;

pub use tarifa::{se_admite, tarifa_minima, tarifa_por_peso};
