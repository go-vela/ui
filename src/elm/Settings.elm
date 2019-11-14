{--
Copyright (c) 2019 Target Brands, Inc. All rights reserved.
Use of this source code is governed by the LICENSE file in this repository.
--}


module Settings exposing (repoUpdateMsg)

import Vela exposing (Field, Repository)



-- HELPERS


{-| repoUpdateMsg : takes update field and updated repo and returns how to alert the user.
-}
repoUpdateMsg : Field -> Repository -> String
repoUpdateMsg field repo =
    let
        prefix =
            msgPrefix field

        suffix =
            msgSuffix field repo
    in
    String.replace "$" repo.full_name <| prefix ++ suffix


{-| msgPrefix : takes update field and returns alert prefix.
-}
msgPrefix : Field -> String
msgPrefix field =
    case field of
        "private" ->
            "$ privacy set to "

        "trusted" ->
            "$ set to "

        "visibility" ->
            "$ visibility set to "

        "allow_pull" ->
            "Pull events for $ "

        "allow_push" ->
            "Push events for $ "

        "allow_deploy" ->
            "Deploy events for $ "

        "allow_tag" ->
            "Tag events for $ "

        _ ->
            "Unrecognized update made to $."


{-| msgSuffix : takes update field and returns alert suffix.
-}
msgSuffix : Field -> Repository -> String
msgSuffix field repo =
    case field of
        "private" ->
            if repo.private then
                "private."

            else
                "public."

        "trusted" ->
            if repo.trusted then
                "trusted."

            else
                "untrusted."

        "visibility" ->
            repo.visibility ++ "."

        "allow_pull" ->
            toggleText repo.allow_pull

        "allow_push" ->
            toggleText repo.allow_push

        "allow_deploy" ->
            toggleText repo.allow_deploy

        "allow_tag" ->
            toggleText repo.allow_tag

        _ ->
            ""


{-| msgSuffix : takes bool value and returns disabled/enabled.
-}
toggleText : Bool -> String
toggleText value =
    if value then
        "enabled."

    else
        "disabled."
