module Components.Secrets exposing (..)

import Components.Table
import FeatherIcons
import Html exposing (Html, a, button, div, span, td, text, tr)
import Html.Attributes exposing (attribute, class, scope)
import Html.Events exposing (onClick)
import Http
import RemoteData exposing (WebData)
import Route.Path
import Shared
import Utils.Helpers as Util
import Vela


type alias Msgs msg =
    { showCopyAlert : String -> msg
    }


type alias Props msg =
    { msgs : Msgs msg
    , secrets : WebData (List Vela.Secret)
    , tableButtons : Maybe (List (Html msg))
    }


{-| viewOrgSecrets : takes secrets model and renders table for viewing org secrets
-}
viewOrgSecrets : Shared.Model -> Props msg -> Html msg
viewOrgSecrets shared props =
    let
        actions =
            Maybe.map
                (\tableButtons -> div [ class "buttons" ] tableButtons)
                props.tableButtons

        ( noRowsView, rows ) =
            case props.secrets of
                RemoteData.Success s ->
                    ( text "No secrets found for this org"
                    , secretsToRows Vela.OrgSecret props.msgs.showCopyAlert s
                    )

                RemoteData.Failure error ->
                    ( span [ Util.testAttribute "org-secrets-error" ]
                        [ text <|
                            case error of
                                Http.BadStatus statusCode ->
                                    case statusCode of
                                        401 ->
                                            "No secrets found for this org, most likely due to not being an admin of the source control org"

                                        _ ->
                                            "No secrets found for this org, there was an error with the server (" ++ String.fromInt statusCode ++ ")"

                                _ ->
                                    "No secrets found for this org, there was an error with the server"
                        ]
                    , []
                    )

                _ ->
                    ( Util.largeLoader, [] )

        cfg =
            Components.Table.Config
                "Org Secrets"
                "org-secrets"
                noRowsView
                tableHeaders
                rows
                actions
    in
    div [] [ Components.Table.view cfg ]


{-| viewRepoSecrets : takes secrets model and renders table for viewing repo secrets
-}
viewRepoSecrets : Shared.Model -> Props msg -> Html msg
viewRepoSecrets shared props =
    let
        actions =
            Maybe.map
                (\tableButtons -> div [ class "buttons" ] tableButtons)
                props.tableButtons

        ( noRowsView, rows ) =
            case props.secrets of
                RemoteData.Success s ->
                    ( text "No secrets found for this repo"
                    , secretsToRows Vela.RepoSecret props.msgs.showCopyAlert s
                    )

                RemoteData.Failure error ->
                    ( span [ Util.testAttribute "repo-secrets-error" ]
                        [ text <|
                            case error of
                                Http.BadStatus statusCode ->
                                    case statusCode of
                                        401 ->
                                            "No secrets found for this repo, most likely due to not being an admin of the source control repo"

                                        _ ->
                                            "No secrets found for this repo, there was an error with the server (" ++ String.fromInt statusCode ++ ")"

                                _ ->
                                    "No secrets found for this repo, there was an error with the server"
                        ]
                    , []
                    )

                _ ->
                    ( Util.largeLoader, [] )

        cfg =
            Components.Table.Config
                "Repo Secrets"
                "repo-secrets"
                noRowsView
                tableHeaders
                rows
                actions
    in
    div [] [ Components.Table.view cfg ]


{-| tableHeaders : returns table headers for secrets table
-}
tableHeaders : Components.Table.Columns
tableHeaders =
    [ ( Just "-icon", "" )
    , ( Nothing, "name" )
    , ( Nothing, "key" )
    , ( Nothing, "type" )
    , ( Nothing, "events" )
    , ( Nothing, "images" )
    , ( Nothing, "allow commands" )
    ]


{-| secretsToRows : takes list of secrets and produces list of Table rows
-}
secretsToRows : Vela.SecretType -> (String -> msg) -> List Vela.Secret -> Components.Table.Rows Vela.Secret msg
secretsToRows type_ copyMsg secrets =
    List.map (\secret -> Components.Table.Row (addKey secret) (viewSecret type_ copyMsg)) secrets


{-| addKey : helper to create secret key
-}
addKey : Vela.Secret -> Vela.Secret
addKey secret =
    case secret.type_ of
        Vela.SharedSecret ->
            { secret | key = secret.org ++ "/" ++ secret.team ++ "/" ++ secret.name }

        Vela.OrgSecret ->
            { secret | key = secret.org ++ "/" ++ secret.name }

        Vela.RepoSecret ->
            { secret | key = secret.org ++ "/" ++ secret.repo ++ "/" ++ secret.name }


{-| viewSecret : takes secret and secret type and renders a table row
-}
viewSecret : Vela.SecretType -> (String -> msg) -> Vela.Secret -> Html msg
viewSecret type_ copyMsg secret =
    tr [ Util.testAttribute <| "secrets-row" ]
        [ td
            [ attribute "data-label" "copy yaml"
            , scope "row"
            , class "break-word"
            , Util.testAttribute <| "secrets-row-copy"
            ]
            [ copyButton (copySecret secret) copyMsg ]
        , td
            [ attribute "data-label" "name"
            , scope "row"
            , class "break-word"
            , class "name"
            , Util.testAttribute <| "secrets-row-name"
            ]
            [ a [ editSecretHref type_ secret ] [ text secret.name ] ]
        , td
            [ attribute "data-label" "key"
            , scope "row"
            , class "break-word"
            , Util.testAttribute <| "secrets-row-key"
            ]
            [ listItemView "key" secret.key
            ]
        , td
            [ attribute "data-label" "type"
            , scope "row"
            , class "break-word"
            ]
            [ text <| Vela.secretTypeToString secret.type_ ]
        , td
            [ attribute "data-label" "events"
            , scope "row"
            , class "break-word"
            ]
            [ viewListCell secret.events "no events" "secret-event" ]
        , td
            [ attribute "data-label" "images"
            , scope "row"
            , class "break-word"
            ]
            [ viewListCell secret.images "all images" "secret-image" ]
        , td
            [ attribute "data-label" "allow command"
            , scope "row"
            , class "break-word"
            ]
            [ text <| Util.boolToYesNo secret.allowCommand ]
        ]


{-| viewListCell : takes list of items, text for none and className and renders a table cell
-}
viewListCell : List String -> String -> String -> Html msg
viewListCell items none itemClassName =
    div [] <|
        if List.length items == 0 then
            [ text none ]

        else
            items
                |> List.sort
                |> List.map
                    (\item ->
                        listItemView itemClassName item
                    )


{-| listItemView : takes classname, text and size constraints and renders a list element
-}
listItemView : String -> String -> Html msg
listItemView className text_ =
    div [ class className ]
        [ span
            [ class "list-item"
            ]
            [ text text_ ]
        ]


{-| copySecret : takes a secret and returns the yaml struct of the secret
-}
copySecret : Vela.Secret -> String
copySecret secret =
    let
        yaml =
            "- name: " ++ secret.name ++ "\n  key: " ++ secret.key ++ "\n  engine: native\n  type: "
    in
    case secret.type_ of
        Vela.OrgSecret ->
            yaml ++ "org"

        Vela.RepoSecret ->
            yaml ++ "repo"

        Vela.SharedSecret ->
            yaml ++ "shared"


{-| copyButton : copy button that copys secret yaml to clipboard
-}
copyButton : String -> (String -> msg) -> Html msg
copyButton copyYaml copyMsg =
    button
        [ class "copy-button"
        , attribute "aria-label" <| "copy secret yaml to clipboard "
        , class "button"
        , class "-icon"
        , onClick <| copyMsg copyYaml
        , attribute "data-clipboard-text" copyYaml
        , Util.testAttribute "copy-secret"
        ]
        [ FeatherIcons.copy
            |> FeatherIcons.withSize 18
            |> FeatherIcons.toHtml []
        ]


{-| editSecretHref : takes secret and secret type and returns href link for routing to view/edit secret page
-}
editSecretHref : Vela.SecretType -> Vela.Secret -> Html.Attribute msg
editSecretHref type_ secret =
    -- let
    --     encodedTeam =
    --         Url.percentEncode secret.team
    --     encodedName =
    --        Url.percentEncode secret.name
    -- in
    Route.Path.href <|
        case type_ of
            Vela.OrgSecret ->
                Route.Path.Org_SecretsEdit_ { org = secret.org, name = secret.name }

            Vela.RepoSecret ->
                Route.Path.Org_Repo_SecretsEdit_ { org = secret.org, repo = secret.repo, name = secret.name }

            Vela.SharedSecret ->
                Route.Path.Org_Secrets { org = secret.org }
