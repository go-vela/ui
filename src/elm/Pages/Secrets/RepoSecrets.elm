{--
Copyright (c) 2020 Target Brands, Inc. All rights reserved.
Use of this source code is governed by the LICENSE file in this repository.
--}


module Pages.Secrets.RepoSecrets exposing (view)

import Api
import Html
    exposing
        ( Html
        , a
        , code
        , div
        , em
        , h4
        , section
        , span
        , text
        )
import Html.Attributes
    exposing
        ( class
        , disabled
        , href
        , placeholder
        , value
        )
import Html.Events exposing (onClick, onInput)
import Pages.Secrets.Types
    exposing
        ( ManageSecretState(..)
        , Msg(..)
        , PartialModel
        )
import RemoteData exposing (RemoteData(..))
import Table.Table
import Util exposing (largeLoader)
import Vela
    exposing
        ( Key
        , Org
        , Repo
        , Secret
        , SecretType
        , Secrets
        , Session
        , Team
        , UpdateSecretPayload
        , buildUpdateSecretPayload
        , encodeUpdateSecret
        , nullSecret
        , secretTypeToString
        , toSecretType
        )



-- VIEW


{-| view : takes model and renders page for managing repo secrets
-}
view : PartialModel a msg -> Html Msg
view model =
    let
        secretsModel =
            model.secretsModel
    in
    case secretsModel.secrets of
        Success secrets ->
            div []
                [ Table.Table.view
                    (Table.Table.Config "Secrets"
                        "No secrets found for this repository"
                        [ "name", "type", "events", "images", "allow command" ]
                        (secretsToRows secrets)
                    )
                ]

        _ ->
            div [] [ largeLoader ]


secretsToRows : Secrets -> Table.Table.Rows Secret Msg
secretsToRows =
    List.map (\secret -> Table.Table.Row secret renderSecret)


renderSecret : Secret -> Html msg
renderSecret secret =
    div [ class "row", class "preview" ]
        [ Table.Table.cell secret.name <| class "host"
        , Table.Table.cell (secretTypeToString secret.type_) <| class ""
        , Table.Table.arrayCell secret.events "no events"
        , Table.Table.arrayCell secret.images "all images"
        , Table.Table.cell (Util.boolToYesNo secret.allowCommand) <| class ""
        ]
