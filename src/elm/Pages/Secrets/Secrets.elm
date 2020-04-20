{--
Copyright (c) 2020 Target Brands, Inc. All rights reserved.
Use of this source code is governed by the LICENSE file in this repository.
--}


module Pages.Secrets.Secrets exposing (view)

import Html
    exposing
        ( Html
        , a
        , div
        , text
        )
import Html.Attributes
    exposing
        ( class
        , href
        )
import Pages.Secrets.Types
    exposing
        ( ManageSecretState(..)
        , Msg(..)
        , PartialModel
        )
import RemoteData exposing (RemoteData(..))
import Routes
import Table.Table
import Util exposing (largeLoader)
import Vela
    exposing
        ( Secret
        , Secrets
        , secretTypeToString
        )



-- VIEW


{-| view : takes model and renders page for managing repo secrets
-}
view : PartialModel a msg -> Html Msg
view model =
    let
        secretsModel =
            model.secretsModel

        ( label, noSecrets, addSecretRoute ) =
            case model.secretsModel.type_ of
                Vela.OrgSecret ->
                    ( "Org Secrets"
                    , "No secrets found for this organization"
                    , Routes.AddOrgSecret "native" secretsModel.org
                    )

                Vela.RepoSecret ->
                    ( "Repo Secrets"
                    , "No secrets found for this repository"
                    , Routes.AddRepoSecret "native" secretsModel.org secretsModel.repo
                    )

                Vela.SharedSecret ->
                    ( "Shared Secrets"
                    , "No secrets found for this organization/team"
                    , Routes.AddSharedSecret "native" secretsModel.org secretsModel.team
                    )

        addSecret =
            Just <|
                a
                    [ class "add-secret"
                    , class "button"
                    , class "-outline"
                    , Routes.href <|
                        addSecretRoute
                    ]
                    [ text "Add Secret" ]
    in
    case secretsModel.secrets of
        Success secrets ->
            div []
                [ Table.Table.view
                    (Table.Table.Config label
                        noSecrets
                        [ "name", "type", "events", "images", "allow command" ]
                        (secretsToRows secrets)
                        addSecret
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
