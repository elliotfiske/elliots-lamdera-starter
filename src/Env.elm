module Env exposing (dummyConfigItem)

-- The Env.elm file is for per-environment configuration.
-- See https://dashboard.lamdera.app/docs/environment for more info.
--
-- Lamdera refuses to deploy an app (previews included) while any value here
-- that the code actually uses has no production value set in the dashboard.
-- This placeholder is unused, so it needs none.


dummyConfigItem : String
dummyConfigItem =
    ""
