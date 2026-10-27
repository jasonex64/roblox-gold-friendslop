--!strict
-- Shared progression types from docs/GATE_D_CONTRACT.md. Pure modules cannot
-- require, so Pure/Profile defines them and this module re-exports them for
-- non-pure code.
local Profile = require(script.Parent.Pure.Profile)

export type Manifest = Profile.Manifest
export type RecordCandidate = Profile.RecordCandidate
export type ProfileData = Profile.Data

return {}
