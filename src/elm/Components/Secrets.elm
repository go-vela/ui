{--
SPDX-License-Identifier: Apache-2.0
--}


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
import Url
import Utils.Helpers as Util
import Vela


type alias Msgs msg =
    { showCopyAlert : String -> msg
    }


type alias Props msg =
    { msgs : Msgs msg
    , engine : String
    , key : String
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
                    ( text <| "No secrets found for the org (" ++ props.key ++ ")"
                    , secretsToRows props.engine Vela.OrgSecret props.msgs.showCopyAlert s
                    )

                RemoteData.Failure error ->
                    ( span [ Util.testAttribute "org-secrets-error" ]
                        [ text <|
                            case error of
                                Http.BadStatus statusCode ->
                                    case statusCode of
                                        401 ->
                                            "No secrets found for the org (" ++ props.key ++ "), most likely due to not being an admin of the source control org"

                                        _ ->
                                            "No secrets found for the org (" ++ props.key ++ "), there was an error with the server (" ++ String.fromInt statusCode ++ ")"

                                _ ->
                                    "No secrets found for the org (" ++ props.key ++ "), there was an error with the server"
                        ]
                    , []
                    )

                _ ->
                    ( Util.smallLoader, [] )

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
                    ( text <| "No secrets found for the repo: (" ++ props.key ++ ")"
                    , secretsToRows props.engine Vela.RepoSecret props.msgs.showCopyAlert s
                    )

                RemoteData.Failure error ->
                    ( span [ Util.testAttribute "repo-secrets-error" ]
                        [ text <|
                            case error of
                                Http.BadStatus statusCode ->
                                    case statusCode of
                                        401 ->
                                            "No secrets found for the repo: (" ++ props.key ++ "), most likely due to not being an admin of the source control repo"

                                        _ ->
                                            "No secrets found for the repo: (" ++ props.key ++ "), there was an error with the server (" ++ String.fromInt statusCode ++ ")"

                                _ ->
                                    "No secrets found for the repo: (" ++ props.key ++ "), there was an error with the server"
                        ]
                    , []
                    )

                _ ->
                    ( Util.smallLoader, [] )

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


{-| viewSharedSecrets : takes secrets model and renders table for viewing shared secrets
-}
viewSharedSecrets : Shared.Model -> Props msg -> Html msg
viewSharedSecrets shared props =
    let
        actions =
            Maybe.map
                (\tableButtons -> div [ class "buttons" ] tableButtons)
                props.tableButtons

        ( noRowsView, rows ) =
            case props.secrets of
                RemoteData.Success s ->
                    ( text <| "No secrets found for the org/team: (" ++ props.key ++ "), most likely due to not being a member of a team within the organization"
                    , secretsToRows props.engine Vela.SharedSecret props.msgs.showCopyAlert s
                    )

                RemoteData.Failure error ->
                    ( span [ Util.testAttribute "repo-secrets-error" ]
                        [ text <|
                            case error of
                                Http.BadStatus statusCode ->
                                    case statusCode of
                                        401 ->
                                            "No secrets found for the org/team: (" ++ props.key ++ "), most likely due to not being a member of a team within the organization"

                                        _ ->
                                            "No secrets found for the org/team: (" ++ props.key ++ "), there was an error with the server (" ++ String.fromInt statusCode ++ ")"

                                _ ->
                                    "No secrets found for the org/team: (" ++ props.key ++ "), there was an error with the server"
                        ]
                    , []
                    )

                _ ->
                    ( Util.smallLoader, [] )

        cfg =
            Components.Table.Config
                "Shared Secrets"
                "shared-secrets"
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
    [ ( Just "table-icon", "" )
    , ( Nothing, "name" )
    , ( Nothing, "key" )
    , ( Nothing, "type" )
    , ( Nothing, "events" )
    , ( Nothing, "images" )
    , ( Nothing, "allow commands" )
    ]


{-| secretsToRows : takes list of secrets and produces list of Table rows
-}
secretsToRows : String -> Vela.SecretType -> (String -> msg) -> List Vela.Secret -> Components.Table.Rows Vela.Secret msg
secretsToRows engine type_ copyMsg secrets =
    List.map (\secret -> Components.Table.Row (addKey secret) (viewSecret engine type_ copyMsg)) secrets


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


appendLabel : Bool -> String -> List String -> List String
appendLabel enabled label inList =
    inList
        ++ (if enabled then
                [ label ]

            else
                []
           )


allowEventsToList : Vela.AllowEvents -> List String
allowEventsToList events =
    [ ( events.push.branch, "push" )
    , ( events.push.tag, "tag" )
    , ( events.pull.opened, "pull_request:opened" )
    , ( events.pull.synchronize, "pull_request:synchronize" )
    , ( events.pull.edited, "pull_request:edited" )
    , ( events.pull.reopened, "pull_request:reopened" )
    , ( events.deploy.created, "deployment" )
    , ( events.comment.created, "comment:created" )
    , ( events.comment.edited, "comment:edited" )
    , ( events.schedule.run, "schedule" )
    ]
        |> List.map
            (\( enabled, label ) ->
                if enabled then
                    Just label

                else
                    Nothing
            )
        |> List.filterMap identity


{-| viewSecret : takes secret and secret type and renders a table row
-}
viewSecret : String -> Vela.SecretType -> (String -> msg) -> Vela.Secret -> Html msg
viewSecret engine type_ copyMsg secret =
    tr [ Util.testAttribute <| "secrets-row" ]
        [ Components.Table.viewIconCell
            { dataLabel = "copy yaml"
            , parentClassList = []
            , itemWrapperClassList = []
            , itemClassList = []
            , children =
                [ copyButton (copySecret secret) copyMsg ]
            }
        , Components.Table.viewItemCell
            { dataLabel = "name"
            , parentClassList = []
            , itemClassList = []
            , children = [ a [ editSecretHref engine type_ secret ] [ text secret.name ] ]
            }
        , Components.Table.viewListItemCell
            { dataLabel = "key"
            , parentClassList = []
            , itemWrapperClassList = [ ( "key", True ) ]
            , itemClassList = []
            , children = [ text secret.key ]
            }
        , Components.Table.viewItemCell
            { dataLabel = "type"
            , parentClassList = []
            , itemClassList = []
            , children = [ text <| Vela.secretTypeToString secret.type_ ]
            }
        , td
            [ attribute "data-label" "events"
            , scope "row"
            , class "break-word"
            ]
            [ Components.Table.viewListCell (allowEventsToList secret.allowEvents) "no events" []
            ]
        , td
            [ attribute "data-label" "images"
            , scope "row"
            , class "break-word"
            ]
            [ Components.Table.viewListCell secret.images "all images" [ ( "secret-image", True ) ] ]
        , Components.Table.viewItemCell
            { dataLabel = "allow command"
            , parentClassList = []
            , itemClassList = []
            , children = [ text <| Util.boolToYesNo secret.allowCommand ]
            }
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
    div []
        [ button
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
        ]


{-| editSecretHref : takes secret and secret type and returns href link for routing to view/edit secret page
-}
editSecretHref : String -> Vela.SecretType -> Vela.Secret -> Html.Attribute msg
editSecretHref engine type_ secret =
    let
        encodedTeam =
            Url.percentEncode secret.team

        encodedName =
            Url.percentEncode secret.name
    in
    Route.Path.href <|
        case type_ of
            Vela.OrgSecret ->
                Route.Path.SecretsEngine_OrgOrg_Edit_
                    { org = secret.org
                    , name = encodedName
                    , engine = engine
                    }

            Vela.RepoSecret ->
                Route.Path.SecretsEngine_RepoOrg_Repo_Edit_
                    { org = secret.org
                    , repo = secret.repo
                    , name = encodedName
                    , engine = engine
                    }

            Vela.SharedSecret ->
                Route.Path.SecretsEngine_SharedOrg_Team_Edit_
                    { org = secret.org
                    , team = encodedTeam
                    , name = secret.name
                    , engine = engine
                    }
