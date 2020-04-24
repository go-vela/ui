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
        , SecretType(..)
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
                        headers
                        (secretsToRows model.secretsModel.type_ secrets)
                        addSecret
                    )
                ]

        _ ->
            div [] [ largeLoader ]


secretsToRows : SecretType -> Secrets -> Table.Table.Rows Secret Msg
secretsToRows type_ =
    List.map (\secret -> Table.Table.Row secret (renderSecret type_))


headers : List String
headers =
    [ "name", "type", "events", "images", "allow command" ]


renderSecret : SecretType -> Secret -> Html msg
renderSecret type_ secret =
    div [ class "row", class "preview" ]
        [ Table.Table.customCell (Html.a [ updateSecretHref type_ secret ] [ text secret.name ]) <| class ""
        , Table.Table.cell (secretTypeToString secret.type_) <| class ""
        , Table.Table.arrayCell secret.events "no events"
        , Table.Table.arrayCell secret.images "all images"
        , Table.Table.cell (Util.boolToYesNo secret.allowCommand) <| class ""

        -- TODO: change linked name to edit button, when table is fixed
        -- , Table.Table.customCell (Html.a [ class "button", class "-outline", updateSecretHref type_ secret ] [ text "edit" ]) <| class ""
        ]


updateSecretHref : SecretType -> Secret -> Html.Attribute msg
updateSecretHref type_ secret =
    Routes.href <|
        case type_ of
            Vela.OrgSecret ->
                Routes.OrgSecret "native" secret.org secret.name

            Vela.RepoSecret ->
                Routes.RepoSecret "native" secret.org secret.repo secret.name

            Vela.SharedSecret ->
                Routes.SharedSecret "native" secret.org secret.team secret.name
