{--
SPDX-License-Identifier: Apache-2.0
--}


module Pages.Secrets.Engine_.Org.Org_ exposing (Model, Msg, page, view)

import Api.Pagination
import Auth
import Components.Pager
import Components.Secrets
import Dict
import Effect exposing (Effect)
import FeatherIcons
import Html exposing (a, text)
import Html.Attributes exposing (class)
import Http
import Http.Detailed
import Layouts
import LinkHeader exposing (WebLink)
import Page exposing (Page)
import RemoteData exposing (WebData)
import Route exposing (Route)
import Route.Path
import Shared
import Svg.Attributes
import Time
import Utils.Errors
import Utils.Helpers as Util
import Utils.Interval as Interval
import Vela
import View exposing (View)


page : Auth.User -> Shared.Model -> Route { engine : String, org : String } -> Page Model Msg
page user shared route =
    Page.new
        { init = init shared route
        , update = update shared route
        , subscriptions = subscriptions
        , view = view shared route
        }
        |> Page.withLayout (toLayout user route)



-- LAYOUT


toLayout : Auth.User -> Route { engine : String, org : String } -> Model -> Layouts.Layout Msg
toLayout user route model =
    Layouts.Default_Org
        { navButtons = []
        , utilButtons = []
        , helpCommands =
            [ { name = "List Org Secrets"
              , content =
                    "vela get secrets --secret.engine native --secret.type org --org "
                        ++ route.params.org
              , docs = Just "secret/get"
              }
            , { name = "List Shared Secrets Help"
              , content = "vela get secrets -h"
              , docs = Just "secret/get"
              }
            , { name = "List Shared Secrets Example"
              , content =
                    "vela get secrets --secret.engine native --secret.type shared --org "
                        ++ route.params.org
                        ++ " --team '*'"
              , docs = Just "secret/get"
              }
            ]
        , crumbs =
            [ ( "Overview", Just Route.Path.Home )
            , ( route.params.org, Nothing )
            ]
        , org = route.params.org
        }



-- INIT


type alias Model =
    { orgSecrets : WebData (List Vela.Secret)
    , sharedSecrets : WebData (List Vela.Secret)
    , pager : List WebLink
    }


init : Shared.Model -> Route { engine : String, org : String } -> () -> ( Model, Effect Msg )
init shared route () =
    ( { orgSecrets = RemoteData.Loading
      , sharedSecrets = RemoteData.Loading
      , pager = []
      }
    , Effect.batch
        [ Effect.getOrgSecrets
            { baseUrl = shared.velaAPIBaseURL
            , session = shared.session
            , onResponse = GetOrgSecretsResponse
            , pageNumber = Dict.get "page" route.query |> Maybe.andThen String.toInt
            , perPage = Dict.get "perPage" route.query |> Maybe.andThen String.toInt
            , engine = route.params.engine
            , org = route.params.org
            }
        , Effect.getSharedSecrets
            { baseUrl = shared.velaAPIBaseURL
            , session = shared.session
            , onResponse = GetSharedSecretsResponse
            , pageNumber = Nothing
            , perPage = Nothing
            , engine = route.params.engine
            , org = route.params.org
            , team = "*"
            }
        ]
    )



-- UPDATE


type Msg
    = -- SECRETS
      GetOrgSecretsResponse (Result (Http.Detailed.Error String) ( Http.Metadata, List Vela.Secret ))
    | GetSharedSecretsResponse (Result (Http.Detailed.Error String) ( Http.Metadata, List Vela.Secret ))
    | GotoPage Int
      -- ALERTS
    | AddAlertCopiedToClipboard String
      -- REFRESH
    | Tick { time : Time.Posix, interval : Interval.Interval }


update : Shared.Model -> Route { engine : String, org : String } -> Msg -> Model -> ( Model, Effect Msg )
update shared route msg model =
    case msg of
        -- SECRETS
        GetOrgSecretsResponse response ->
            case response of
                Ok ( meta, secrets ) ->
                    ( { model
                        | orgSecrets = RemoteData.Success secrets
                        , pager = Api.Pagination.get meta.headers
                      }
                    , Effect.none
                    )

                Err error ->
                    ( { model | orgSecrets = Utils.Errors.toFailure error }
                    , Effect.handleHttpError { httpError = error }
                    )

        GetSharedSecretsResponse response ->
            case response of
                Ok ( _, secrets ) ->
                    ( { model
                        | sharedSecrets = RemoteData.Success secrets
                      }
                    , Effect.none
                    )

                Err error ->
                    ( { model | sharedSecrets = Utils.Errors.toFailure error }
                    , Effect.none
                    )

        GotoPage pageNumber ->
            ( model
            , Effect.batch
                [ Effect.pushRoute
                    { path = route.path
                    , query =
                        Dict.update "page" (\_ -> Just <| String.fromInt pageNumber) route.query
                    , hash = route.hash
                    }
                , Effect.getOrgSecrets
                    { baseUrl = shared.velaAPIBaseURL
                    , session = shared.session
                    , onResponse = GetOrgSecretsResponse
                    , pageNumber = Just pageNumber
                    , perPage = Dict.get "perPage" route.query |> Maybe.andThen String.toInt
                    , engine = route.params.engine
                    , org = route.params.org
                    }
                ]
            )

        -- ALERTS
        AddAlertCopiedToClipboard contentCopied ->
            ( model
            , Effect.addAlertSuccess
                { content = "'" ++ contentCopied ++ "' copied to clipboard."
                , addToastIfUnique = False
                , link = Nothing
                }
            )

        -- REFRESH
        Tick options ->
            ( model
            , Effect.batch
                [ Effect.getOrgSecrets
                    { baseUrl = shared.velaAPIBaseURL
                    , session = shared.session
                    , onResponse = GetOrgSecretsResponse
                    , pageNumber = Dict.get "page" route.query |> Maybe.andThen String.toInt
                    , perPage = Dict.get "perPage" route.query |> Maybe.andThen String.toInt
                    , engine = route.params.engine
                    , org = route.params.org
                    }
                , Effect.getSharedSecrets
                    { baseUrl = shared.velaAPIBaseURL
                    , session = shared.session
                    , onResponse = GetSharedSecretsResponse
                    , pageNumber = Nothing
                    , perPage = Nothing
                    , engine = route.params.engine
                    , org = route.params.org
                    , team = "*"
                    }
                ]
            )



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    Interval.tickEveryFiveSeconds Tick



-- VIEW


view : Shared.Model -> Route { engine : String, org : String } -> Model -> View Msg
view shared route model =
    { title = "Secrets" ++ Util.pageToString (Dict.get "page" route.query)
    , body =
        [ Components.Secrets.viewOrgSecrets shared
            { msgs =
                { showCopyAlert = AddAlertCopiedToClipboard
                }
            , engine = route.params.engine
            , key = route.params.org
            , secrets = model.orgSecrets
            , tableButtons =
                Just
                    [ a
                        [ class "button"
                        , class "-outline"
                        , class "button-with-icon"
                        , Util.testAttribute "add-org-secret"
                        , Route.Path.href <|
                            Route.Path.SecretsEngine_OrgOrg_Add
                                { engine = route.params.engine
                                , org = route.params.org
                                }
                        ]
                        [ text "Add Org Secret"
                        , FeatherIcons.plus
                            |> FeatherIcons.withSize 18
                            |> FeatherIcons.toHtml [ Svg.Attributes.class "button-icon" ]
                        ]
                    , Components.Pager.view model.pager Components.Pager.defaultLabels GotoPage
                    ]
            }
        , Components.Pager.view model.pager Components.Pager.defaultLabels GotoPage
        , Components.Secrets.viewSharedSecrets shared
            { msgs =
                { showCopyAlert = AddAlertCopiedToClipboard
                }
            , engine = route.params.engine
            , key = route.params.org ++ "/*"
            , secrets = model.sharedSecrets
            , tableButtons =
                Just
                    [ a
                        [ class "button"
                        , class "-outline"
                        , class "button-with-icon"
                        , Util.testAttribute "manage-shared-secrets"
                        , Route.Path.href <|
                            Route.Path.SecretsEngine_SharedOrg_Team_
                                { engine = route.params.engine
                                , org = route.params.org
                                , team = "*"
                                }
                        ]
                        [ text "Manage Shared Secrets"
                        , FeatherIcons.plus
                            |> FeatherIcons.withSize 18
                            |> FeatherIcons.toHtml [ Svg.Attributes.class "button-icon" ]
                        ]
                    ]
            }
        ]
    }
