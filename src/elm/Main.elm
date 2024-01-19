{--
SPDX-License-Identifier: Apache-2.0
--}


module Main exposing (main)

import Api.Api
import Api.Operations_
import Auth
import Auth.Action
import Auth.Jwt exposing (JwtAccessToken, JwtAccessTokenClaims, extractJwtClaims)
import Auth.Session exposing (Session(..), SessionDetails, refreshAccessToken)
import Browser
import Browser.Events exposing (Visibility(..))
import Browser.Navigation
import Components.Alerts as Alerts exposing (Alert)
import Dict
import Effect exposing (Effect)
import Http
import Http.Detailed
import Interop
import Json.Decode
import Json.Encode
import Layout
import Layouts exposing (Layout)
import Layouts.Default
import Layouts.Default.Org
import Layouts.Default.Repo
import Main.Layouts.Model
import Main.Layouts.Msg
import Main.Pages.Model
import Main.Pages.Msg
import Maybe
import Maybe.Extra exposing (unwrap)
import Page
import Pages.Account.Login_
import Pages.Account.Settings_
import Pages.Account.SourceRepos_
import Pages.Home_
import Pages.NotFound_
import Pages.Org_.Repo_
import Pages.Org_.Repo_.Deployments_
import Pages.Org_Repos
import RemoteData exposing (RemoteData(..), WebData)
import Route exposing (Route)
import Route.Path
import Shared
import Task
import Time
    exposing
        ( Posix
        , Zone
        , every
        , here
        )
import Toasty as Alerting exposing (Stack)
import Url exposing (Url)
import Utils.Errors as Errors exposing (Error, addErrorString)
import Utils.Interval as Interval exposing (Interval(..), RefreshData)
import Vela
import View exposing (View)


main : Program Json.Decode.Value Model Msg
main =
    Browser.application
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        , onUrlRequest = UrlRequested
        , onUrlChange = UrlChanged
        }



-- INIT


type alias Model =
    { key : Browser.Navigation.Key
    , url : Url
    , page : Main.Pages.Model.Model
    , shared : Shared.Model
    , layout : Maybe Main.Layouts.Model.Model
    }


init : Json.Decode.Value -> Url -> Browser.Navigation.Key -> ( Model, Cmd Msg )
init json url key =
    let
        flagsResult : Result Json.Decode.Error Shared.Flags
        flagsResult =
            Json.Decode.decodeValue Shared.decoder json

        ( sharedModel, sharedEffect ) =
            Shared.init flagsResult (Route.fromUrl () url)

        { page, layout } =
            initPageAndLayout { key = key, url = url, shared = sharedModel, layout = Nothing }

        setTimeZone : Cmd Msg
        setTimeZone =
            Task.perform AdjustTimeZone here

        setTime : Cmd Msg
        setTime =
            Task.perform AdjustTime Time.now

        fetchInitialTokenCmd =
            if String.length sharedModel.velaRedirect == 0 then
                Api.Api.try TokenResponse <| Api.Operations_.getToken sharedModel.velaAPI

            else
                Cmd.none
    in
    ( { url = url
      , key = key
      , page = Tuple.first page
      , layout = layout |> Maybe.map Tuple.first
      , shared = sharedModel
      }
    , Cmd.batch
        [ Tuple.second page
        , layout |> Maybe.map Tuple.second |> Maybe.withDefault Cmd.none
        , fromSharedEffect { key = key, url = url, shared = sharedModel } sharedEffect

        -- custom initialization effects
        , Interop.setTheme <| Vela.encodeTheme sharedModel.theme
        , setTimeZone
        , setTime
        , fetchInitialTokenCmd
        ]
    )


initLayout : { key : Browser.Navigation.Key, url : Url, shared : Shared.Model, layout : Maybe Main.Layouts.Model.Model } -> Layouts.Layout Msg -> ( Main.Layouts.Model.Model, Cmd Msg )
initLayout model layout =
    case ( layout, model.layout ) of
        ( Layouts.Default props, Just (Main.Layouts.Model.Default existing) ) ->
            ( Main.Layouts.Model.Default existing
            , Cmd.none
            )

        ( Layouts.Default props, Just (Main.Layouts.Model.Default_Org existing) ) ->
            ( Main.Layouts.Model.Default { default = existing.default }
            , Cmd.none
            )

        ( Layouts.Default props, _ ) ->
            let
                route : Route ()
                route =
                    Route.fromUrl () model.url

                defaultLayout =
                    Layouts.Default.layout props model.shared route

                ( defaultLayoutModel, defaultLayoutEffect ) =
                    Layout.init defaultLayout ()
            in
            ( Main.Layouts.Model.Default { default = defaultLayoutModel }
            , fromLayoutEffect model (Effect.map Main.Layouts.Msg.Default defaultLayoutEffect)
            )

        ( Layouts.Default_Org props, Just (Main.Layouts.Model.Default existing) ) ->
            let
                route : Route ()
                route =
                    Route.fromUrl () model.url

                defaultNestedLayout =
                    Layouts.Default.Org.layout props model.shared route

                ( nestedLayoutModel, nestedLayoutEffect ) =
                    Layout.init defaultNestedLayout ()
            in
            ( Main.Layouts.Model.Default_Org { default = existing.default, org = nestedLayoutModel }
            , fromLayoutEffect model (Effect.map Main.Layouts.Msg.Default_Org nestedLayoutEffect)
            )

        ( Layouts.Default_Org props, Just (Main.Layouts.Model.Default_Org existing) ) ->
            ( Main.Layouts.Model.Default_Org existing
            , Cmd.none
            )

        ( Layouts.Default_Org props, _ ) ->
            let
                route : Route ()
                route =
                    Route.fromUrl () model.url

                defaultNestedLayout =
                    Layouts.Default.Org.layout props model.shared route

                defaultLayout =
                    Layouts.Default.layout (Layout.parentProps defaultNestedLayout) model.shared route

                ( nestedLayoutModel, nestedLayoutEffect ) =
                    Layout.init defaultNestedLayout ()

                ( defaultLayoutModel, defaultLayoutEffect ) =
                    Layout.init defaultLayout ()
            in
            ( Main.Layouts.Model.Default_Org { default = defaultLayoutModel, org = nestedLayoutModel }
            , Cmd.batch
                [ fromLayoutEffect model (Effect.map Main.Layouts.Msg.Default_Org nestedLayoutEffect)
                , fromLayoutEffect model (Effect.map Main.Layouts.Msg.Default defaultLayoutEffect)
                ]
            )

        ( Layouts.Default_Repo props, Just (Main.Layouts.Model.Default existing) ) ->
            let
                route : Route ()
                route =
                    Route.fromUrl () model.url

                defaultNestedLayout =
                    Layouts.Default.Repo.layout props model.shared route

                ( nestedLayoutModel, nestedLayoutEffect ) =
                    Layout.init defaultNestedLayout ()
            in
            ( Main.Layouts.Model.Default_Repo { default = existing.default, repo = nestedLayoutModel }
            , fromLayoutEffect model (Effect.map Main.Layouts.Msg.Default_Repo nestedLayoutEffect)
            )

        ( Layouts.Default_Repo props, Just (Main.Layouts.Model.Default_Repo existing) ) ->
            ( Main.Layouts.Model.Default_Repo existing
            , Cmd.none
            )

        ( Layouts.Default_Repo props, _ ) ->
            let
                route : Route ()
                route =
                    Route.fromUrl () model.url

                defaultNestedLayout =
                    Layouts.Default.Repo.layout props model.shared route

                defaultLayout =
                    Layouts.Default.layout (Layout.parentProps defaultNestedLayout) model.shared route

                ( nestedLayoutModel, nestedLayoutEffect ) =
                    Layout.init defaultNestedLayout ()

                ( defaultLayoutModel, defaultLayoutEffect ) =
                    Layout.init defaultLayout ()
            in
            ( Main.Layouts.Model.Default_Repo { default = defaultLayoutModel, repo = nestedLayoutModel }
            , Cmd.batch
                [ fromLayoutEffect model (Effect.map Main.Layouts.Msg.Default_Repo nestedLayoutEffect)
                , fromLayoutEffect model (Effect.map Main.Layouts.Msg.Default defaultLayoutEffect)
                ]
            )


initPageAndLayout :
    { key : Browser.Navigation.Key
    , url : Url
    , shared : Shared.Model
    , layout : Maybe Main.Layouts.Model.Model
    }
    ->
        { page : ( Main.Pages.Model.Model, Cmd Msg )
        , layout : Maybe ( Main.Layouts.Model.Model, Cmd Msg )
        }
initPageAndLayout model =
    case Route.Path.fromUrl model.url of
        Route.Path.Login_ ->
            let
                page : Page.Page Pages.Account.Login_.Model Pages.Account.Login_.Msg
                page =
                    Pages.Account.Login_.page model.shared (Route.fromUrl () model.url)

                ( pageModel, pageEffect ) =
                    Page.init page ()
            in
            { page =
                Tuple.mapBoth
                    Main.Pages.Model.AccountLogin_
                    (Effect.map Main.Pages.Msg.AccountLogin_ >> fromPageEffect model)
                    ( pageModel, pageEffect )
            , layout =
                Page.layout pageModel page
                    |> Maybe.map (Layouts.map (Main.Pages.Msg.AccountLogin_ >> Page))
                    |> Maybe.map (initLayout model)
            }

        Route.Path.AccountSettings_ ->
            runWhenAuthenticatedWithLayout
                model
                (\user ->
                    let
                        page : Page.Page Pages.Account.Settings_.Model Pages.Account.Settings_.Msg
                        page =
                            Pages.Account.Settings_.page user model.shared (Route.fromUrl () model.url)

                        ( pageModel, pageEffect ) =
                            Page.init page ()
                    in
                    { page =
                        Tuple.mapBoth
                            Main.Pages.Model.AccountSettings_
                            (Effect.map Main.Pages.Msg.AccountSettings_ >> fromPageEffect model)
                            ( pageModel, pageEffect )
                    , layout =
                        Page.layout pageModel page
                            |> Maybe.map (Layouts.map (Main.Pages.Msg.AccountSettings_ >> Page))
                            |> Maybe.map (initLayout model)
                    }
                )

        Route.Path.AccountSourceRepos_ ->
            runWhenAuthenticatedWithLayout
                model
                (\user ->
                    let
                        page : Page.Page Pages.Account.SourceRepos_.Model Pages.Account.SourceRepos_.Msg
                        page =
                            Pages.Account.SourceRepos_.page user model.shared (Route.fromUrl () model.url)

                        ( pageModel, pageEffect ) =
                            Page.init page ()
                    in
                    { page =
                        Tuple.mapBoth
                            Main.Pages.Model.AccountSourceRepos_
                            (Effect.map Main.Pages.Msg.AccountSourceRepos_ >> fromPageEffect model)
                            ( pageModel, pageEffect )
                    , layout =
                        Page.layout pageModel page
                            |> Maybe.map (Layouts.map (Main.Pages.Msg.AccountSourceRepos_ >> Page))
                            |> Maybe.map (initLayout model)
                    }
                )

        Route.Path.Logout_ ->
            { page =
                ( Main.Pages.Model.Redirecting_
                , Effect.logout {} |> Effect.toCmd { key = model.key, url = model.url, shared = model.shared, fromSharedMsg = Shared, batch = Batch, toCmd = Task.succeed >> Task.perform identity }
                )
            , layout = Nothing
            }

        Route.Path.Authenticate_ ->
            let
                route =
                    Route.fromUrl () model.url

                code =
                    Dict.get "code" route.query

                state =
                    Dict.get "state" route.query
            in
            { page =
                ( Main.Pages.Model.Redirecting_
                , Cmd.batch
                    [ Api.Api.try TokenResponse <|
                        Api.Operations_.finishAuthentication model.shared.velaAPI <|
                            Vela.AuthParams code state
                    ]
                )
            , layout = Nothing
            }

        Route.Path.Home_ ->
            runWhenAuthenticatedWithLayout
                model
                (\user ->
                    let
                        page : Page.Page Pages.Home_.Model Pages.Home_.Msg
                        page =
                            Pages.Home_.page user model.shared (Route.fromUrl () model.url)

                        ( pageModel, pageEffect ) =
                            Page.init page ()
                    in
                    { page =
                        Tuple.mapBoth
                            Main.Pages.Model.Home_
                            (Effect.map Main.Pages.Msg.Home_ >> fromPageEffect model)
                            ( pageModel, pageEffect )
                    , layout =
                        Page.layout pageModel page
                            |> Maybe.map (Layouts.map (Main.Pages.Msg.Home_ >> Page))
                            |> Maybe.map (initLayout model)
                    }
                )

        Route.Path.Org_Repos params ->
            runWhenAuthenticatedWithLayout
                model
                (\user ->
                    let
                        page : Page.Page Pages.Org_Repos.Model Pages.Org_Repos.Msg
                        page =
                            Pages.Org_Repos.page user model.shared (Route.fromUrl params model.url)

                        ( pageModel, pageEffect ) =
                            Page.init page ()
                    in
                    { page =
                        Tuple.mapBoth
                            (Main.Pages.Model.Org_Repos params)
                            (Effect.map Main.Pages.Msg.Org_Repos >> fromPageEffect model)
                            ( pageModel, pageEffect )
                    , layout =
                        Page.layout pageModel page
                            |> Maybe.map (Layouts.map (Main.Pages.Msg.Org_Repos >> Page))
                            |> Maybe.map (initLayout model)
                    }
                )

        Route.Path.Org_Repo_ params ->
            runWhenAuthenticatedWithLayout
                model
                (\user ->
                    let
                        page : Page.Page Pages.Org_.Repo_.Model Pages.Org_.Repo_.Msg
                        page =
                            Pages.Org_.Repo_.page user model.shared (Route.fromUrl params model.url)

                        ( pageModel, pageEffect ) =
                            Page.init page ()
                    in
                    { page =
                        Tuple.mapBoth
                            (Main.Pages.Model.Org_Repo_ params)
                            (Effect.map Main.Pages.Msg.Org_Repo_ >> fromPageEffect model)
                            ( pageModel, pageEffect )
                    , layout =
                        Page.layout pageModel page
                            |> Maybe.map (Layouts.map (Main.Pages.Msg.Org_Repo_ >> Page))
                            |> Maybe.map (initLayout model)
                    }
                )

        Route.Path.Org_Repo_Deployments_ params ->
            runWhenAuthenticatedWithLayout
                model
                (\user ->
                    let
                        page : Page.Page Pages.Org_.Repo_.Deployments_.Model Pages.Org_.Repo_.Deployments_.Msg
                        page =
                            Pages.Org_.Repo_.Deployments_.page user model.shared (Route.fromUrl params model.url)

                        ( pageModel, pageEffect ) =
                            Page.init page ()
                    in
                    { page =
                        Tuple.mapBoth
                            (Main.Pages.Model.Org_Repo_Deployments_ params)
                            (Effect.map Main.Pages.Msg.Org_Repo_Deployments_ >> fromPageEffect model)
                            ( pageModel, pageEffect )
                    , layout =
                        Page.layout pageModel page
                            |> Maybe.map (Layouts.map (Main.Pages.Msg.Org_Repo_Deployments_ >> Page))
                            |> Maybe.map (initLayout model)
                    }
                )

        Route.Path.NotFound_ ->
            let
                page : Page.Page Pages.NotFound_.Model Pages.NotFound_.Msg
                page =
                    Pages.NotFound_.page model.shared (Route.fromUrl () model.url)

                ( pageModel, pageEffect ) =
                    Page.init page ()
            in
            { page =
                Tuple.mapBoth
                    Main.Pages.Model.NotFound_
                    (Effect.map Main.Pages.Msg.NotFound_ >> fromPageEffect model)
                    ( pageModel, pageEffect )
            , layout =
                Page.layout pageModel page
                    |> Maybe.map (Layouts.map (Main.Pages.Msg.NotFound_ >> Page))
                    |> Maybe.map (initLayout model)
            }


runWhenAuthenticated : { model | shared : Shared.Model, url : Url, key : Browser.Navigation.Key } -> (Auth.User -> ( Main.Pages.Model.Model, Cmd Msg )) -> ( Main.Pages.Model.Model, Cmd Msg )
runWhenAuthenticated model toTuple =
    let
        record =
            runWhenAuthenticatedWithLayout model (\user -> { page = toTuple user, layout = Nothing })
    in
    record.page


runWhenAuthenticatedWithLayout : { model | shared : Shared.Model, url : Url, key : Browser.Navigation.Key } -> (Auth.User -> { page : ( Main.Pages.Model.Model, Cmd Msg ), layout : Maybe ( Main.Layouts.Model.Model, Cmd Msg ) }) -> { page : ( Main.Pages.Model.Model, Cmd Msg ), layout : Maybe ( Main.Layouts.Model.Model, Cmd Msg ) }
runWhenAuthenticatedWithLayout model toRecord =
    let
        authAction : Auth.Action.Action Auth.User
        authAction =
            Auth.onPageLoad model.shared (Route.fromUrl () model.url)

        toCmd : Effect Msg -> Cmd Msg
        toCmd =
            Effect.toCmd
                { key = model.key
                , url = model.url
                , shared = model.shared
                , fromSharedMsg = Shared
                , batch = Batch
                , toCmd = Task.succeed >> Task.perform identity
                }
    in
    case authAction of
        Auth.Action.LoadPageWithUser user ->
            toRecord user

        Auth.Action.ShowLoadingPage loadingView ->
            { page =
                ( Main.Pages.Model.Loading_
                , Cmd.none
                )
            , layout = Nothing
            }

        Auth.Action.ReplaceRoute options ->
            { page =
                ( Main.Pages.Model.Redirecting_
                , toCmd (Effect.replaceRoute options)
                )
            , layout = Nothing
            }

        Auth.Action.PushRoute options ->
            { page =
                ( Main.Pages.Model.Redirecting_
                , Cmd.batch
                    [ toCmd (Effect.pushRoute options)
                    , unwrap Cmd.none (\from -> Interop.setRedirect <| Json.Encode.string from) (Dict.get "from" options.query)
                    ]
                )
            , layout = Nothing
            }

        Auth.Action.LoadExternalUrl externalUrl ->
            { page =
                ( Main.Pages.Model.Redirecting_
                , Browser.Navigation.load externalUrl
                )
            , layout = Nothing
            }



-- UPDATE


type Msg
    = UrlRequested Browser.UrlRequest
    | UrlChanged Url
    | Page Main.Pages.Msg.Msg
    | Layout Main.Layouts.Msg.Msg
    | Shared Shared.Msg
    | Batch (List Msg)
      -- AUTH
    | TokenResponse (Result (Http.Detailed.Error String) ( Http.Metadata, JwtAccessToken ))
    | RefreshAccessToken
      -- Time
    | AdjustTimeZone Zone
    | AdjustTime Posix
    | Tick Interval Posix
      -- Other
    | HandleError Error
    | AlertsUpdate (Alerting.Msg Alert)


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    let
        shared =
            model.shared
    in
    case msg of
        UrlRequested (Browser.Internal url) ->
            ( model
            , Browser.Navigation.pushUrl model.key (Url.toString url)
            )

        UrlRequested (Browser.External url) ->
            ( model
            , Browser.Navigation.load url
            )

        UrlChanged url ->
            if Route.Path.fromUrl url == Route.Path.fromUrl model.url then
                let
                    newModel : Model
                    newModel =
                        { model | url = url }
                in
                ( newModel
                , Cmd.batch
                    [ toPageUrlHookCmd newModel
                        { from = Route.fromUrl () model.url
                        , to = Route.fromUrl () newModel.url
                        }
                    , toLayoutUrlHookCmd model
                        newModel
                        { from = Route.fromUrl () model.url
                        , to = Route.fromUrl () newModel.url
                        }
                    ]
                )

            else
                let
                    { page, layout } =
                        initPageAndLayout { key = model.key, shared = model.shared, layout = model.layout, url = url }

                    ( pageModel, pageCmd ) =
                        page

                    ( layoutModel, layoutCmd ) =
                        case layout of
                            Just ( layoutModel_, layoutCmd_ ) ->
                                ( Just layoutModel_, layoutCmd_ )

                            Nothing ->
                                ( Nothing, Cmd.none )

                    newModel =
                        { model | url = url, page = pageModel, layout = layoutModel }
                in
                ( newModel
                , Cmd.batch
                    [ pageCmd
                    , layoutCmd
                    , toLayoutUrlHookCmd model
                        newModel
                        { from = Route.fromUrl () model.url
                        , to = Route.fromUrl () newModel.url
                        }
                    ]
                )

        Page pageMsg ->
            let
                ( pageModel, pageCmd ) =
                    updateFromPage pageMsg model
            in
            ( { model | page = pageModel }
            , pageCmd
            )

        Layout layoutMsg ->
            let
                ( layoutModel, layoutCmd ) =
                    updateFromLayout layoutMsg model
            in
            ( { model | layout = layoutModel }
            , layoutCmd
            )

        Shared sharedMsg ->
            let
                ( sharedModel, sharedEffect ) =
                    Shared.update (Route.fromUrl () model.url) sharedMsg model.shared

                ( oldAction, newAction ) =
                    ( Auth.onPageLoad model.shared (Route.fromUrl () model.url)
                    , Auth.onPageLoad sharedModel (Route.fromUrl () model.url)
                    )
            in
            if isAuthProtected (Route.fromUrl () model.url).path && hasActionTypeChanged oldAction newAction then
                let
                    { layout, page } =
                        initPageAndLayout { key = model.key, shared = sharedModel, url = model.url, layout = model.layout }

                    ( pageModel, pageCmd ) =
                        page

                    ( layoutModel, layoutCmd ) =
                        ( layout |> Maybe.map Tuple.first
                        , layout |> Maybe.map Tuple.second |> Maybe.withDefault Cmd.none
                        )
                in
                ( { model | shared = sharedModel, page = pageModel, layout = layoutModel }
                , Cmd.batch
                    [ pageCmd
                    , layoutCmd
                    , fromSharedEffect { model | shared = sharedModel } sharedEffect
                    ]
                )

            else
                ( { model | shared = sharedModel }
                , fromSharedEffect { model | shared = sharedModel } sharedEffect
                )

        Batch messages ->
            ( model
            , messages
                |> List.map (Task.succeed >> Task.perform identity)
                |> Cmd.batch
            )

        TokenResponse response ->
            let
                route =
                    Route.fromUrl () model.url

                -- todo: how do we capture the scenario where
                -- the user is logged off a page and we need to
                -- redirect them back to the page they were on?
                velaRedirect =
                    case shared.velaRedirect of
                        "" ->
                            case Dict.get "from" route.query of
                                Just f ->
                                    f

                                Nothing ->
                                    "/"

                        _ ->
                            shared.velaRedirect
            in
            case response of
                Ok ( _, token ) ->
                    let
                        currentSession : Session
                        currentSession =
                            model.shared.session

                        payload : JwtAccessTokenClaims
                        payload =
                            extractJwtClaims token

                        newSessionDetails : SessionDetails
                        newSessionDetails =
                            SessionDetails token payload.exp payload.sub

                        actions : List (Cmd Msg)
                        actions =
                            case currentSession of
                                Unauthenticated ->
                                    [ Browser.Navigation.pushUrl model.key velaRedirect
                                    ]

                                Authenticated _ ->
                                    []
                    in
                    ( { model
                        | shared =
                            { shared
                                | session = Authenticated newSessionDetails
                                , velaRedirect = ""
                            }
                      }
                    , Cmd.batch <|
                        actions
                            ++ [ Interop.setRedirect Json.Encode.null
                               , refreshAccessToken RefreshAccessToken newSessionDetails
                               ]
                    )

                Err error ->
                    let
                        redirectPage =
                            case model.page of
                                Main.Pages.Model.AccountLogin_ _ ->
                                    Cmd.none

                                _ ->
                                    Browser.Navigation.pushUrl model.key <| Route.Path.toString Route.Path.Login_
                    in
                    case error of
                        Http.Detailed.BadStatus meta _ ->
                            case meta.statusCode of
                                401 ->
                                    let
                                        actions : List (Cmd Msg)
                                        actions =
                                            case model.shared.session of
                                                Unauthenticated ->
                                                    [ redirectPage
                                                    , Interop.setRedirect <| Json.Encode.string velaRedirect
                                                    ]

                                                Authenticated _ ->
                                                    [ addErrorString "Your session has expired or you logged in somewhere else, please log in again." HandleError
                                                    , redirectPage
                                                    , Interop.setRedirect <| Json.Encode.string velaRedirect
                                                    ]
                                    in
                                    ( { model
                                        | shared =
                                            { shared
                                                | session =
                                                    Unauthenticated
                                                , velaRedirect = velaRedirect
                                            }
                                      }
                                    , Cmd.batch actions
                                    )

                                _ ->
                                    ( { model
                                        | shared =
                                            { shared
                                                | session = Unauthenticated
                                                , velaRedirect = velaRedirect
                                            }
                                      }
                                    , Cmd.batch
                                        [ Errors.addError HandleError error
                                        , redirectPage
                                        ]
                                    )

                        _ ->
                            ( { model
                                | shared =
                                    { shared
                                        | session = Unauthenticated
                                        , velaRedirect = velaRedirect
                                    }
                              }
                            , Cmd.batch
                                [ Errors.addError HandleError error
                                , redirectPage
                                ]
                            )

        RefreshAccessToken ->
            ( model, Api.Api.try TokenResponse <| Api.Operations_.getToken shared.velaAPI )

        -- Time
        AdjustTimeZone newZone ->
            ( { model | shared = { shared | zone = newZone } }
            , Cmd.none
            )

        AdjustTime newTime ->
            ( { model | shared = { shared | time = newTime } }
            , Cmd.none
            )

        Tick interval time ->
            ( model, Cmd.none )

        -- case interval of
        --     OneSecond ->
        --         let
        --             ( favicon, updateFavicon ) =
        --                 refreshFavicon model.legacyPage model.shared.favicon rm.build.build
        --         in
        --         ( { model | shared = { shared | time = time, favicon = favicon } }
        --         , Cmd.batch
        --             [ updateFavicon
        --             , refreshRenderBuildGraph model
        --             ]
        --         )
        --     FiveSecond ->
        --         ( model, refreshPage model )
        --     OneSecondHidden ->
        --         let
        --             ( favicon, cmd ) =
        --                 refreshFavicon model.legacyPage model.shared.favicon rm.build.build
        --         in
        --         ( { model | shared = { shared | time = time, favicon = favicon } }, cmd )
        --     FiveSecondHidden data ->
        --         ( model, refreshPageHidden model data )
        -- Other
        HandleError error ->
            let
                ( sharedWithAlert, cmd ) =
                    Alerting.addToastIfUnique Alerts.errorConfig AlertsUpdate (Alerts.Error "Error" error) ( model.shared, Cmd.none )
            in
            ( { model | shared = sharedWithAlert }, cmd )

        AlertsUpdate subMsg ->
            let
                ( sharedWithAlert, cmd ) =
                    Alerting.update Alerts.successConfig AlertsUpdate subMsg model.shared
            in
            ( { model | shared = sharedWithAlert }, cmd )


updateFromPage : Main.Pages.Msg.Msg -> Model -> ( Main.Pages.Model.Model, Cmd Msg )
updateFromPage msg model =
    case ( msg, model.page ) of
        ( Main.Pages.Msg.AccountLogin_ pageMsg, Main.Pages.Model.AccountLogin_ pageModel ) ->
            Tuple.mapBoth
                Main.Pages.Model.AccountLogin_
                (Effect.map Main.Pages.Msg.AccountLogin_ >> fromPageEffect model)
                (Page.update (Pages.Account.Login_.page model.shared (Route.fromUrl () model.url)) pageMsg pageModel)

        ( Main.Pages.Msg.AccountSettings_ pageMsg, Main.Pages.Model.AccountSettings_ pageModel ) ->
            runWhenAuthenticated
                model
                (\user ->
                    Tuple.mapBoth
                        Main.Pages.Model.AccountSettings_
                        (Effect.map Main.Pages.Msg.AccountSettings_ >> fromPageEffect model)
                        (Page.update (Pages.Account.Settings_.page user model.shared (Route.fromUrl () model.url)) pageMsg pageModel)
                )

        ( Main.Pages.Msg.AccountSourceRepos_ pageMsg, Main.Pages.Model.AccountSourceRepos_ pageModel ) ->
            runWhenAuthenticated
                model
                (\user ->
                    Tuple.mapBoth
                        Main.Pages.Model.AccountSourceRepos_
                        (Effect.map Main.Pages.Msg.AccountSourceRepos_ >> fromPageEffect model)
                        (Page.update (Pages.Account.SourceRepos_.page user model.shared (Route.fromUrl () model.url)) pageMsg pageModel)
                )

        ( Main.Pages.Msg.Home_ pageMsg, Main.Pages.Model.Home_ pageModel ) ->
            runWhenAuthenticated
                model
                (\user ->
                    Tuple.mapBoth
                        Main.Pages.Model.Home_
                        (Effect.map Main.Pages.Msg.Home_ >> fromPageEffect model)
                        (Page.update (Pages.Home_.page user model.shared (Route.fromUrl () model.url)) pageMsg pageModel)
                )

        ( Main.Pages.Msg.Org_Repos pageMsg, Main.Pages.Model.Org_Repos params pageModel ) ->
            runWhenAuthenticated
                model
                (\user ->
                    Tuple.mapBoth
                        (Main.Pages.Model.Org_Repos params)
                        (Effect.map Main.Pages.Msg.Org_Repos >> fromPageEffect model)
                        (Page.update (Pages.Org_Repos.page user model.shared (Route.fromUrl params model.url)) pageMsg pageModel)
                )

        ( Main.Pages.Msg.Org_Repo_ pageMsg, Main.Pages.Model.Org_Repo_ params pageModel ) ->
            runWhenAuthenticated
                model
                (\user ->
                    Tuple.mapBoth
                        (Main.Pages.Model.Org_Repo_ params)
                        (Effect.map Main.Pages.Msg.Org_Repo_ >> fromPageEffect model)
                        (Page.update (Pages.Org_.Repo_.page user model.shared (Route.fromUrl params model.url)) pageMsg pageModel)
                )

        ( Main.Pages.Msg.Org_Repo_Deployments_ pageMsg, Main.Pages.Model.Org_Repo_Deployments_ params pageModel ) ->
            runWhenAuthenticated
                model
                (\user ->
                    Tuple.mapBoth
                        (Main.Pages.Model.Org_Repo_Deployments_ params)
                        (Effect.map Main.Pages.Msg.Org_Repo_Deployments_ >> fromPageEffect model)
                        (Page.update (Pages.Org_.Repo_.Deployments_.page user model.shared (Route.fromUrl params model.url)) pageMsg pageModel)
                )

        ( Main.Pages.Msg.NotFound_ pageMsg, Main.Pages.Model.NotFound_ pageModel ) ->
            Tuple.mapBoth
                Main.Pages.Model.NotFound_
                (Effect.map Main.Pages.Msg.NotFound_ >> fromPageEffect model)
                (Page.update (Pages.NotFound_.page model.shared (Route.fromUrl () model.url)) pageMsg pageModel)

        -- when you add a new page, remember to fill in this case
        _ ->
            ( model.page
            , Cmd.none
            )


updateFromLayout : Main.Layouts.Msg.Msg -> Model -> ( Maybe Main.Layouts.Model.Model, Cmd Msg )
updateFromLayout msg model =
    let
        route : Route ()
        route =
            Route.fromUrl () model.url
    in
    case ( toLayoutFromPage model, model.layout, msg ) of
        ( Just (Layouts.Default props), Just (Main.Layouts.Model.Default layoutModel), Main.Layouts.Msg.Default layoutMsg ) ->
            Tuple.mapBoth
                (\newModel -> Just (Main.Layouts.Model.Default { layoutModel | default = newModel }))
                (Effect.map Main.Layouts.Msg.Default >> fromLayoutEffect model)
                (Layout.update (Layouts.Default.layout props model.shared route) layoutMsg layoutModel.default)

        ( Just (Layouts.Default_Org props), Just (Main.Layouts.Model.Default_Org layoutModel), Main.Layouts.Msg.Default layoutMsg ) ->
            let
                defaultProps =
                    Layouts.Default.Org.layout props model.shared route
                        |> Layout.parentProps
            in
            Tuple.mapBoth
                (\newModel -> Just (Main.Layouts.Model.Default_Org { layoutModel | default = newModel }))
                (Effect.map Main.Layouts.Msg.Default >> fromLayoutEffect model)
                (Layout.update (Layouts.Default.layout defaultProps model.shared route) layoutMsg layoutModel.default)

        ( Just (Layouts.Default_Org props), Just (Main.Layouts.Model.Default_Org layoutModel), Main.Layouts.Msg.Default_Org layoutMsg ) ->
            Tuple.mapBoth
                (\newModel -> Just (Main.Layouts.Model.Default_Org { layoutModel | org = newModel }))
                (Effect.map Main.Layouts.Msg.Default_Org >> fromLayoutEffect model)
                (Layout.update (Layouts.Default.Org.layout props model.shared route) layoutMsg layoutModel.org)

        ( Just (Layouts.Default_Repo props), Just (Main.Layouts.Model.Default_Repo layoutModel), Main.Layouts.Msg.Default layoutMsg ) ->
            let
                defaultProps =
                    Layouts.Default.Repo.layout props model.shared route
                        |> Layout.parentProps
            in
            Tuple.mapBoth
                (\newModel -> Just (Main.Layouts.Model.Default_Repo { layoutModel | default = newModel }))
                (Effect.map Main.Layouts.Msg.Default >> fromLayoutEffect model)
                (Layout.update (Layouts.Default.layout defaultProps model.shared route) layoutMsg layoutModel.default)

        ( Just (Layouts.Default_Repo props), Just (Main.Layouts.Model.Default_Repo layoutModel), Main.Layouts.Msg.Default_Repo layoutMsg ) ->
            Tuple.mapBoth
                (\newModel -> Just (Main.Layouts.Model.Default_Repo { layoutModel | repo = newModel }))
                (Effect.map Main.Layouts.Msg.Default_Repo >> fromLayoutEffect model)
                (Layout.update (Layouts.Default.Repo.layout props model.shared route) layoutMsg layoutModel.repo)

        _ ->
            ( model.layout
            , Cmd.none
            )


toLayoutFromPage : Model -> Maybe (Layouts.Layout Msg)
toLayoutFromPage model =
    case model.page of
        Main.Pages.Model.AccountLogin_ pageModel ->
            Route.fromUrl () model.url
                |> Pages.Account.Login_.page model.shared
                |> Page.layout pageModel
                |> Maybe.map (Layouts.map (Main.Pages.Msg.AccountLogin_ >> Page))

        Main.Pages.Model.AccountSettings_ pageModel ->
            Route.fromUrl () model.url
                |> toAuthProtectedPage model Pages.Account.Settings_.page
                |> Maybe.andThen (Page.layout pageModel)
                |> Maybe.map (Layouts.map (Main.Pages.Msg.AccountSettings_ >> Page))

        Main.Pages.Model.AccountSourceRepos_ pageModel ->
            Route.fromUrl () model.url
                |> toAuthProtectedPage model Pages.Account.SourceRepos_.page
                |> Maybe.andThen (Page.layout pageModel)
                |> Maybe.map (Layouts.map (Main.Pages.Msg.AccountSourceRepos_ >> Page))

        Main.Pages.Model.Home_ pageModel ->
            Route.fromUrl () model.url
                |> toAuthProtectedPage model Pages.Home_.page
                |> Maybe.andThen (Page.layout pageModel)
                |> Maybe.map (Layouts.map (Main.Pages.Msg.Home_ >> Page))

        Main.Pages.Model.Org_Repos params pageModel ->
            Route.fromUrl params model.url
                |> toAuthProtectedPage model Pages.Org_Repos.page
                |> Maybe.andThen (Page.layout pageModel)
                |> Maybe.map (Layouts.map (Main.Pages.Msg.Org_Repos >> Page))

        Main.Pages.Model.Org_Repo_ params pageModel ->
            Route.fromUrl params model.url
                |> toAuthProtectedPage model Pages.Org_.Repo_.page
                |> Maybe.andThen (Page.layout pageModel)
                |> Maybe.map (Layouts.map (Main.Pages.Msg.Org_Repo_ >> Page))

        Main.Pages.Model.Org_Repo_Deployments_ params pageModel ->
            Route.fromUrl params model.url
                |> toAuthProtectedPage model Pages.Org_.Repo_.Deployments_.page
                |> Maybe.andThen (Page.layout pageModel)
                |> Maybe.map (Layouts.map (Main.Pages.Msg.Org_Repo_Deployments_ >> Page))

        Main.Pages.Model.NotFound_ pageModel ->
            Route.fromUrl () model.url
                |> Pages.NotFound_.page model.shared
                |> Page.layout pageModel
                |> Maybe.map (Layouts.map (Main.Pages.Msg.NotFound_ >> Page))

        Main.Pages.Model.Redirecting_ ->
            Nothing

        Main.Pages.Model.Loading_ ->
            Nothing


toAuthProtectedPage : Model -> (Auth.User -> Shared.Model -> Route params -> Page.Page model msg) -> Route params -> Maybe (Page.Page model msg)
toAuthProtectedPage model toPage route =
    case Auth.onPageLoad model.shared (Route.fromUrl () model.url) of
        Auth.Action.LoadPageWithUser user ->
            Just (toPage user model.shared route)

        _ ->
            Nothing


hasActionTypeChanged : Auth.Action.Action user -> Auth.Action.Action user -> Bool
hasActionTypeChanged oldAction newAction =
    case ( newAction, oldAction ) of
        ( Auth.Action.LoadPageWithUser _, Auth.Action.LoadPageWithUser _ ) ->
            False

        ( Auth.Action.ShowLoadingPage _, Auth.Action.ShowLoadingPage _ ) ->
            False

        ( Auth.Action.ReplaceRoute _, Auth.Action.ReplaceRoute _ ) ->
            False

        ( Auth.Action.PushRoute _, Auth.Action.PushRoute _ ) ->
            False

        ( Auth.Action.LoadExternalUrl _, Auth.Action.LoadExternalUrl _ ) ->
            False

        ( _, _ ) ->
            True


subscriptions : Model -> Sub Msg
subscriptions model =
    let
        subscriptionsFromPage : Sub Msg
        subscriptionsFromPage =
            case model.page of
                Main.Pages.Model.AccountLogin_ pageModel ->
                    Page.subscriptions (Pages.Account.Login_.page model.shared (Route.fromUrl () model.url)) pageModel
                        |> Sub.map Main.Pages.Msg.AccountLogin_
                        |> Sub.map Page

                Main.Pages.Model.AccountSettings_ pageModel ->
                    Sub.none

                Main.Pages.Model.AccountSourceRepos_ pageModel ->
                    Sub.none

                Main.Pages.Model.Home_ pageModel ->
                    Sub.none

                Main.Pages.Model.Org_Repos params pageModel ->
                    Auth.Action.subscriptions
                        (\user ->
                            Page.subscriptions (Pages.Org_Repos.page user model.shared (Route.fromUrl params model.url)) pageModel
                                |> Sub.map Main.Pages.Msg.Org_Repos
                                |> Sub.map Page
                        )
                        (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

                Main.Pages.Model.Org_Repo_ params pageModel ->
                    Auth.Action.subscriptions
                        (\user ->
                            Page.subscriptions (Pages.Org_.Repo_.page user model.shared (Route.fromUrl params model.url)) pageModel
                                |> Sub.map Main.Pages.Msg.Org_Repo_
                                |> Sub.map Page
                        )
                        (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

                Main.Pages.Model.Org_Repo_Deployments_ params pageModel ->
                    Auth.Action.subscriptions
                        (\user ->
                            Page.subscriptions (Pages.Org_.Repo_.Deployments_.page user model.shared (Route.fromUrl params model.url)) pageModel
                                |> Sub.map Main.Pages.Msg.Org_Repo_Deployments_
                                |> Sub.map Page
                        )
                        (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

                Main.Pages.Model.NotFound_ pageModel ->
                    Page.subscriptions (Pages.NotFound_.page model.shared (Route.fromUrl () model.url)) pageModel
                        |> Sub.map Main.Pages.Msg.NotFound_
                        |> Sub.map Page

                Main.Pages.Model.Redirecting_ ->
                    Sub.none

                Main.Pages.Model.Loading_ ->
                    Sub.none

        maybeLayout : Maybe (Layouts.Layout Msg)
        maybeLayout =
            toLayoutFromPage model

        route : Route ()
        route =
            Route.fromUrl () model.url

        subscriptionsFromLayout : Sub Msg
        subscriptionsFromLayout =
            case ( maybeLayout, model.layout ) of
                ( Just (Layouts.Default props), Just (Main.Layouts.Model.Default layoutModel) ) ->
                    Layout.subscriptions (Layouts.Default.layout props model.shared route) layoutModel.default
                        |> Sub.map Main.Layouts.Msg.Default
                        |> Sub.map Layout

                ( Just (Layouts.Default_Org props), Just (Main.Layouts.Model.Default_Org layoutModel) ) ->
                    let
                        defaultProps =
                            Layouts.Default.Org.layout props model.shared route
                                |> Layout.parentProps
                    in
                    Sub.batch
                        [ Layout.subscriptions (Layouts.Default.layout defaultProps model.shared route) layoutModel.default
                            |> Sub.map Main.Layouts.Msg.Default
                            |> Sub.map Layout
                        , Layout.subscriptions (Layouts.Default.Org.layout props model.shared route) layoutModel.org
                            |> Sub.map Main.Layouts.Msg.Default_Org
                            |> Sub.map Layout
                        ]

                ( Just (Layouts.Default_Repo props), Just (Main.Layouts.Model.Default_Repo layoutModel) ) ->
                    let
                        defaultProps =
                            Layouts.Default.Repo.layout props model.shared route
                                |> Layout.parentProps
                    in
                    Sub.batch
                        [ Layout.subscriptions (Layouts.Default.layout defaultProps model.shared route) layoutModel.default
                            |> Sub.map Main.Layouts.Msg.Default
                            |> Sub.map Layout
                        , Layout.subscriptions (Layouts.Default.Repo.layout props model.shared route) layoutModel.repo
                            |> Sub.map Main.Layouts.Msg.Default_Repo
                            |> Sub.map Layout
                        ]

                _ ->
                    Sub.none
    in
    Sub.batch
        [ Shared.subscriptions route model.shared
            |> Sub.map Shared
        , subscriptionsFromPage
        , subscriptionsFromLayout
        ]



-- VIEW


view : Model -> Browser.Document Msg
view model =
    let
        view_ : View Msg
        view_ =
            toView model

        -- |> legacyLayout model
    in
    View.toBrowserDocument
        { shared = model.shared
        , route = Route.fromUrl () model.url
        , view = view_
        }


toView : Model -> View Msg
toView model =
    let
        route : Route ()
        route =
            Route.fromUrl () model.url
    in
    case ( toLayoutFromPage model, model.layout ) of
        ( Just (Layouts.Default props), Just (Main.Layouts.Model.Default layoutModel) ) ->
            Layout.view
                (Layouts.Default.layout props model.shared route)
                { model = layoutModel.default
                , toContentMsg = Main.Layouts.Msg.Default >> Layout
                , content = viewPage model
                }

        ( Just (Layouts.Default_Org props), Just (Main.Layouts.Model.Default_Org layoutModel) ) ->
            let
                defaultProps =
                    Layouts.Default.Org.layout props model.shared route
                        |> Layout.parentProps
            in
            Layout.view
                (Layouts.Default.layout defaultProps model.shared route)
                { model = layoutModel.default
                , toContentMsg = Main.Layouts.Msg.Default >> Layout
                , content =
                    Layout.view
                        (Layouts.Default.Org.layout props model.shared route)
                        { model = layoutModel.org
                        , toContentMsg = Main.Layouts.Msg.Default_Org >> Layout
                        , content = viewPage model
                        }
                }

        ( Just (Layouts.Default_Repo props), Just (Main.Layouts.Model.Default_Repo layoutModel) ) ->
            let
                defaultProps =
                    Layouts.Default.Repo.layout props model.shared route
                        |> Layout.parentProps
            in
            Layout.view
                (Layouts.Default.layout defaultProps model.shared route)
                { model = layoutModel.default
                , toContentMsg = Main.Layouts.Msg.Default >> Layout
                , content =
                    Layout.view
                        (Layouts.Default.Repo.layout props model.shared route)
                        { model = layoutModel.repo
                        , toContentMsg = Main.Layouts.Msg.Default_Repo >> Layout
                        , content = viewPage model
                        }
                }

        _ ->
            viewPage model


viewPage : Model -> View Msg
viewPage model =
    case model.page of
        Main.Pages.Model.AccountLogin_ pageModel ->
            Page.view (Pages.Account.Login_.page model.shared (Route.fromUrl () model.url)) pageModel
                |> View.map Main.Pages.Msg.AccountLogin_
                |> View.map Page

        Main.Pages.Model.AccountSettings_ pageModel ->
            Auth.Action.view
                (\user ->
                    Page.view (Pages.Account.Settings_.page user model.shared (Route.fromUrl () model.url)) pageModel
                        |> View.map Main.Pages.Msg.AccountSettings_
                        |> View.map Page
                )
                (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

        Main.Pages.Model.AccountSourceRepos_ pageModel ->
            Auth.Action.view
                (\user ->
                    Page.view (Pages.Account.SourceRepos_.page user model.shared (Route.fromUrl () model.url)) pageModel
                        |> View.map Main.Pages.Msg.AccountSourceRepos_
                        |> View.map Page
                )
                (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

        Main.Pages.Model.Home_ pageModel ->
            Auth.Action.view
                (\user ->
                    Page.view (Pages.Home_.page user model.shared (Route.fromUrl () model.url)) pageModel
                        |> View.map Main.Pages.Msg.Home_
                        |> View.map Page
                )
                (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

        Main.Pages.Model.Org_Repos params pageModel ->
            Auth.Action.view
                (\user ->
                    Page.view (Pages.Org_Repos.page user model.shared (Route.fromUrl params model.url)) pageModel
                        |> View.map Main.Pages.Msg.Org_Repos
                        |> View.map Page
                )
                (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

        Main.Pages.Model.Org_Repo_ params pageModel ->
            Auth.Action.view
                (\user ->
                    Page.view (Pages.Org_.Repo_.page user model.shared (Route.fromUrl params model.url)) pageModel
                        |> View.map Main.Pages.Msg.Org_Repo_
                        |> View.map Page
                )
                (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

        Main.Pages.Model.Org_Repo_Deployments_ params pageModel ->
            Auth.Action.view
                (\user ->
                    Page.view (Pages.Org_.Repo_.Deployments_.page user model.shared (Route.fromUrl params model.url)) pageModel
                        |> View.map Main.Pages.Msg.Org_Repo_Deployments_
                        |> View.map Page
                )
                (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

        Main.Pages.Model.NotFound_ pageModel ->
            Page.view (Pages.NotFound_.page model.shared (Route.fromUrl () model.url)) pageModel
                |> View.map Main.Pages.Msg.NotFound_
                |> View.map Page

        Main.Pages.Model.Redirecting_ ->
            View.none

        Main.Pages.Model.Loading_ ->
            Auth.viewLoadingPage model.shared (Route.fromUrl () model.url)
                |> View.map never



-- INTERNALS


fromPageEffect : { model | key : Browser.Navigation.Key, url : Url, shared : Shared.Model } -> Effect Main.Pages.Msg.Msg -> Cmd Msg
fromPageEffect model effect =
    Effect.toCmd
        { key = model.key
        , url = model.url
        , shared = model.shared
        , fromSharedMsg = Shared
        , batch = Batch
        , toCmd = Task.succeed >> Task.perform identity
        }
        (Effect.map Page effect)


fromLayoutEffect : { model | key : Browser.Navigation.Key, url : Url, shared : Shared.Model } -> Effect Main.Layouts.Msg.Msg -> Cmd Msg
fromLayoutEffect model effect =
    Effect.toCmd
        { key = model.key
        , url = model.url
        , shared = model.shared
        , fromSharedMsg = Shared
        , batch = Batch
        , toCmd = Task.succeed >> Task.perform identity
        }
        (Effect.map Layout effect)


fromSharedEffect : { model | key : Browser.Navigation.Key, url : Url, shared : Shared.Model } -> Effect Shared.Msg -> Cmd Msg
fromSharedEffect model effect =
    Effect.toCmd
        { key = model.key
        , url = model.url
        , shared = model.shared
        , fromSharedMsg = Shared
        , batch = Batch
        , toCmd = Task.succeed >> Task.perform identity
        }
        (Effect.map Shared effect)



-- URL HOOKS FOR PAGES


toPageUrlHookCmd : Model -> { from : Route (), to : Route () } -> Cmd Msg
toPageUrlHookCmd model routes =
    let
        toCommands messages =
            messages
                |> List.map (Task.succeed >> Task.perform identity)
                |> Cmd.batch
    in
    case model.page of
        Main.Pages.Model.AccountLogin_ pageModel ->
            Page.toUrlMessages routes (Pages.Account.Login_.page model.shared (Route.fromUrl () model.url))
                |> List.map Main.Pages.Msg.AccountLogin_
                |> List.map Page
                |> toCommands

        Main.Pages.Model.AccountSettings_ pageModel ->
            Auth.Action.command
                (\user ->
                    Page.toUrlMessages routes (Pages.Account.Settings_.page user model.shared (Route.fromUrl () model.url))
                        |> List.map Main.Pages.Msg.AccountSettings_
                        |> List.map Page
                        |> toCommands
                )
                (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

        Main.Pages.Model.AccountSourceRepos_ pageModel ->
            Auth.Action.command
                (\user ->
                    Page.toUrlMessages routes (Pages.Account.SourceRepos_.page user model.shared (Route.fromUrl () model.url))
                        |> List.map Main.Pages.Msg.AccountSourceRepos_
                        |> List.map Page
                        |> toCommands
                )
                (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

        Main.Pages.Model.Home_ pageModel ->
            Auth.Action.command
                (\user ->
                    Page.toUrlMessages routes (Pages.Home_.page user model.shared (Route.fromUrl () model.url))
                        |> List.map Main.Pages.Msg.Home_
                        |> List.map Page
                        |> toCommands
                )
                (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

        Main.Pages.Model.Org_Repos params pageModel ->
            Auth.Action.command
                (\user ->
                    Page.toUrlMessages routes (Pages.Org_Repos.page user model.shared (Route.fromUrl params model.url))
                        |> List.map Main.Pages.Msg.Org_Repos
                        |> List.map Page
                        |> toCommands
                )
                (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

        Main.Pages.Model.Org_Repo_ params pageModel ->
            Auth.Action.command
                (\user ->
                    Page.toUrlMessages routes (Pages.Org_.Repo_.page user model.shared (Route.fromUrl params model.url))
                        |> List.map Main.Pages.Msg.Org_Repo_
                        |> List.map Page
                        |> toCommands
                )
                (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

        Main.Pages.Model.Org_Repo_Deployments_ params pageModel ->
            Auth.Action.command
                (\user ->
                    Page.toUrlMessages routes (Pages.Org_.Repo_.Deployments_.page user model.shared (Route.fromUrl params model.url))
                        |> List.map Main.Pages.Msg.Org_Repo_Deployments_
                        |> List.map Page
                        |> toCommands
                )
                (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

        Main.Pages.Model.NotFound_ pageModel ->
            Page.toUrlMessages routes (Pages.NotFound_.page model.shared (Route.fromUrl () model.url))
                |> List.map Main.Pages.Msg.NotFound_
                |> List.map Page
                |> toCommands

        Main.Pages.Model.Redirecting_ ->
            Cmd.none

        Main.Pages.Model.Loading_ ->
            Cmd.none


toLayoutUrlHookCmd : Model -> Model -> { from : Route (), to : Route () } -> Cmd Msg
toLayoutUrlHookCmd oldModel model routes =
    let
        toCommands messages =
            if shouldFireUrlChangedEvents then
                messages
                    |> List.map (Task.succeed >> Task.perform identity)
                    |> Cmd.batch

            else
                Cmd.none

        shouldFireUrlChangedEvents =
            hasNavigatedWithinNewLayout
                { from = toLayoutFromPage oldModel
                , to = toLayoutFromPage model
                }

        route =
            Route.fromUrl () model.url
    in
    case ( toLayoutFromPage model, model.layout ) of
        ( Just (Layouts.Default props), Just (Main.Layouts.Model.Default layoutModel) ) ->
            Layout.toUrlMessages routes (Layouts.Default.layout props model.shared route)
                |> List.map Main.Layouts.Msg.Default
                |> List.map Layout
                |> toCommands

        ( Just (Layouts.Default_Org props), Just (Main.Layouts.Model.Default_Org layoutModel) ) ->
            let
                defaultProps =
                    Layouts.Default.Org.layout props model.shared route
                        |> Layout.parentProps
            in
            Cmd.batch
                [ Layout.toUrlMessages routes (Layouts.Default.layout defaultProps model.shared route)
                    |> List.map Main.Layouts.Msg.Default
                    |> List.map Layout
                    |> toCommands
                , Layout.toUrlMessages routes (Layouts.Default.Org.layout props model.shared route)
                    |> List.map Main.Layouts.Msg.Default_Org
                    |> List.map Layout
                    |> toCommands
                ]

        ( Just (Layouts.Default_Repo props), Just (Main.Layouts.Model.Default_Repo layoutModel) ) ->
            let
                defaultProps =
                    Layouts.Default.Repo.layout props model.shared route
                        |> Layout.parentProps
            in
            Cmd.batch
                [ Layout.toUrlMessages routes (Layouts.Default.layout defaultProps model.shared route)
                    |> List.map Main.Layouts.Msg.Default
                    |> List.map Layout
                    |> toCommands
                , Layout.toUrlMessages routes (Layouts.Default.Repo.layout props model.shared route)
                    |> List.map Main.Layouts.Msg.Default_Repo
                    |> List.map Layout
                    |> toCommands
                ]

        _ ->
            Cmd.none


hasNavigatedWithinNewLayout : { from : Maybe (Layouts.Layout msg), to : Maybe (Layouts.Layout msg) } -> Bool
hasNavigatedWithinNewLayout { from, to } =
    let
        isRelated maybePair =
            case maybePair of
                Just ( Layouts.Default _, Layouts.Default _ ) ->
                    True

                Just ( Layouts.Default_Org _, Layouts.Default_Org _ ) ->
                    True

                Just ( Layouts.Default_Org _, Layouts.Default _ ) ->
                    True

                Just ( Layouts.Default_Repo _, Layouts.Default_Repo _ ) ->
                    True

                Just ( Layouts.Default_Repo _, Layouts.Default _ ) ->
                    True

                _ ->
                    False
    in
    List.any isRelated
        [ Maybe.map2 Tuple.pair from to
        , Maybe.map2 Tuple.pair to from
        ]


isAuthProtected : Route.Path.Path -> Bool
isAuthProtected routePath =
    case routePath of
        Route.Path.Login_ ->
            False

        Route.Path.Logout_ ->
            True

        Route.Path.Authenticate_ ->
            False

        Route.Path.AccountSettings_ ->
            True

        Route.Path.AccountSourceRepos_ ->
            True

        Route.Path.Home_ ->
            True

        Route.Path.Org_Repos _ ->
            True

        Route.Path.Org_Repo_ _ ->
            True

        Route.Path.Org_Repo_Deployments_ _ ->
            True

        Route.Path.NotFound_ ->
            False
