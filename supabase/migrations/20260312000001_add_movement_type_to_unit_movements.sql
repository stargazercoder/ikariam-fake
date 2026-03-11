-- Migration: add movement_type column to unit_movements
-- movement_type distinguishes attack from return trips (and future reinforce in v2 CMBT-06).
-- Default 'attack' so all existing rows are correctly classified.

ALTER TABLE public.unit_movements
  ADD COLUMN movement_type text NOT NULL DEFAULT 'attack'
  CHECK (movement_type IN ('attack', 'return'));
