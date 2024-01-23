{--
SPDX-License-Identifier: Apache-2.0
--}
--todo: known issues:
-- favicon fails to load sometimes on fresh visit
-- not found redirects are weird, refreshing 404 goes to the home page?


module Main exposing (main)

import Auth
import Auth.Action
import Browser
import Browser.Navigation
import Dict
import Effect exposing (Effect)
import Interop
import Json.Decode
import Json.Encode
import Layout
import Layouts exposing (Layout)
import Layouts.Default
import Layouts.Default.Build
import Layouts.Default.Org
import Layouts.Default.Repo
import Main.Layouts.Model
import Main.Layouts.Msg
import Main.Pages.Model
import Main.Pages.Msg
import Maybe
import Maybe.Extra
import Page
import Pages.Account.Login
import Pages.Account.Settings
import Pages.Account.SourceRepos
import Pages.Home
import Pages.NotFound_
import Pages.Org_
import Pages.Org_.Builds
import Pages.Org_.Repo_
import Pages.Org_.Repo_.Audit
import Pages.Org_.Repo_.Build_
import Pages.Org_.Repo_.Build_.Services
import Pages.Org_.Repo_.Deployments
import Pages.Org_.Repo_.Schedules
import Pages.Org_.Repo_.Secrets
import Pages.Org_.Repo_.Secrets.Add
import Pages.Org_.Repo_.Secrets.Edit_
import Pages.Org_.Secrets
import Pages.Org_.Secrets.Add
import Pages.Org_.Secrets.Edit_
import Route exposing (Route)
import Route.Path
import Shared
import Task
import Url exposing (Url)
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

        ( Layouts.Default_Build props, Just (Main.Layouts.Model.Default existing) ) ->
            let
                route : Route ()
                route =
                    Route.fromUrl () model.url

                defaultNestedLayout =
                    Layouts.Default.Build.layout props model.shared route

                ( nestedLayoutModel, nestedLayoutEffect ) =
                    Layout.init defaultNestedLayout ()
            in
            ( Main.Layouts.Model.Default_Build { default = existing.default, repo = nestedLayoutModel }
            , fromLayoutEffect model (Effect.map Main.Layouts.Msg.Default_Build nestedLayoutEffect)
            )

        ( Layouts.Default_Build props, Just (Main.Layouts.Model.Default_Build existing) ) ->
            ( Main.Layouts.Model.Default_Build existing
            , Cmd.none
            )

        ( Layouts.Default_Build props, _ ) ->
            let
                route : Route ()
                route =
                    Route.fromUrl () model.url

                defaultNestedLayout =
                    Layouts.Default.Build.layout props model.shared route

                defaultLayout =
                    Layouts.Default.layout (Layout.parentProps defaultNestedLayout) model.shared route

                ( nestedLayoutModel, nestedLayoutEffect ) =
                    Layout.init defaultNestedLayout ()

                ( defaultLayoutModel, defaultLayoutEffect ) =
                    Layout.init defaultLayout ()
            in
            ( Main.Layouts.Model.Default_Build { default = defaultLayoutModel, repo = nestedLayoutModel }
            , Cmd.batch
                [ fromLayoutEffect model (Effect.map Main.Layouts.Msg.Default_Build nestedLayoutEffect)
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
        Route.Path.AccountLogin ->
            let
                page : Page.Page Pages.Account.Login.Model Pages.Account.Login.Msg
                page =
                    Pages.Account.Login.page model.shared (Route.fromUrl () model.url)

                ( pageModel, pageEffect ) =
                    Page.init page ()
            in
            { page =
                Tuple.mapBoth
                    Main.Pages.Model.AccountLogin
                    (Effect.map Main.Pages.Msg.AccountLogin >> fromPageEffect model)
                    ( pageModel, pageEffect )
            , layout =
                Page.layout pageModel page
                    |> Maybe.map (Layouts.map (Main.Pages.Msg.AccountLogin >> Page))
                    |> Maybe.map (initLayout model)
            }

        Route.Path.AccountSettings ->
            runWhenAuthenticatedWithLayout
                model
                (\user ->
                    let
                        page : Page.Page Pages.Account.Settings.Model Pages.Account.Settings.Msg
                        page =
                            Pages.Account.Settings.page user model.shared (Route.fromUrl () model.url)

                        ( pageModel, pageEffect ) =
                            Page.init page ()
                    in
                    { page =
                        Tuple.mapBoth
                            Main.Pages.Model.AccountSettings
                            (Effect.map Main.Pages.Msg.AccountSettings >> fromPageEffect model)
                            ( pageModel, pageEffect )
                    , layout =
                        Page.layout pageModel page
                            |> Maybe.map (Layouts.map (Main.Pages.Msg.AccountSettings >> Page))
                            |> Maybe.map (initLayout model)
                    }
                )

        Route.Path.AccountSourceRepos ->
            runWhenAuthenticatedWithLayout
                model
                (\user ->
                    let
                        page : Page.Page Pages.Account.SourceRepos.Model Pages.Account.SourceRepos.Msg
                        page =
                            Pages.Account.SourceRepos.page user model.shared (Route.fromUrl () model.url)

                        ( pageModel, pageEffect ) =
                            Page.init page ()
                    in
                    { page =
                        Tuple.mapBoth
                            Main.Pages.Model.AccountSourceRepos
                            (Effect.map Main.Pages.Msg.AccountSourceRepos >> fromPageEffect model)
                            ( pageModel, pageEffect )
                    , layout =
                        Page.layout pageModel page
                            |> Maybe.map (Layouts.map (Main.Pages.Msg.AccountSourceRepos >> Page))
                            |> Maybe.map (initLayout model)
                    }
                )

        Route.Path.AccountLogout ->
            -- todo: fix: this is firing twice
            -- once on initial logout, with 200
            -- then again on logout response, with 401
            { page =
                ( Main.Pages.Model.Redirecting_
                , Effect.logout
                    { from = Dict.get "from" (Route.fromUrl () model.url).query }
                    |> Effect.toCmd
                        { key = model.key
                        , url = model.url
                        , shared = model.shared
                        , fromSharedMsg = Shared
                        , batch = Batch
                        , toCmd = Task.succeed >> Task.perform identity
                        }
                )
            , layout = Nothing
            }

        Route.Path.AccountAuthenticate_ ->
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
                , Effect.finishAuthentication { code = code, state = state }
                    |> Effect.toCmd { key = model.key, url = model.url, shared = model.shared, fromSharedMsg = Shared, batch = Batch, toCmd = Task.succeed >> Task.perform identity }
                )
            , layout = Nothing
            }

        Route.Path.Home ->
            runWhenAuthenticatedWithLayout
                model
                (\user ->
                    let
                        page : Page.Page Pages.Home.Model Pages.Home.Msg
                        page =
                            Pages.Home.page user model.shared (Route.fromUrl () model.url)

                        ( pageModel, pageEffect ) =
                            Page.init page ()
                    in
                    { page =
                        Tuple.mapBoth
                            Main.Pages.Model.Home
                            (Effect.map Main.Pages.Msg.Home >> fromPageEffect model)
                            ( pageModel, pageEffect )
                    , layout =
                        Page.layout pageModel page
                            |> Maybe.map (Layouts.map (Main.Pages.Msg.Home >> Page))
                            |> Maybe.map (initLayout model)
                    }
                )

        Route.Path.Org_ params ->
            runWhenAuthenticatedWithLayout
                model
                (\user ->
                    let
                        page : Page.Page Pages.Org_.Model Pages.Org_.Msg
                        page =
                            Pages.Org_.page user model.shared (Route.fromUrl params model.url)

                        ( pageModel, pageEffect ) =
                            Page.init page ()
                    in
                    { page =
                        Tuple.mapBoth
                            (Main.Pages.Model.Org_ params)
                            (Effect.map Main.Pages.Msg.Org_ >> fromPageEffect model)
                            ( pageModel, pageEffect )
                    , layout =
                        Page.layout pageModel page
                            |> Maybe.map (Layouts.map (Main.Pages.Msg.Org_ >> Page))
                            |> Maybe.map (initLayout model)
                    }
                )

        Route.Path.Org_Builds params ->
            runWhenAuthenticatedWithLayout
                model
                (\user ->
                    let
                        page : Page.Page Pages.Org_.Builds.Model Pages.Org_.Builds.Msg
                        page =
                            Pages.Org_.Builds.page user model.shared (Route.fromUrl params model.url)

                        ( pageModel, pageEffect ) =
                            Page.init page ()
                    in
                    { page =
                        Tuple.mapBoth
                            (Main.Pages.Model.Org_Builds params)
                            (Effect.map Main.Pages.Msg.Org_Builds >> fromPageEffect model)
                            ( pageModel, pageEffect )
                    , layout =
                        Page.layout pageModel page
                            |> Maybe.map (Layouts.map (Main.Pages.Msg.Org_Builds >> Page))
                            |> Maybe.map (initLayout model)
                    }
                )

        Route.Path.Org_Secrets params ->
            runWhenAuthenticatedWithLayout
                model
                (\user ->
                    let
                        page : Page.Page Pages.Org_.Secrets.Model Pages.Org_.Secrets.Msg
                        page =
                            Pages.Org_.Secrets.page user model.shared (Route.fromUrl params model.url)

                        ( pageModel, pageEffect ) =
                            Page.init page ()
                    in
                    { page =
                        Tuple.mapBoth
                            (Main.Pages.Model.Org_Secrets params)
                            (Effect.map Main.Pages.Msg.Org_Secrets >> fromPageEffect model)
                            ( pageModel, pageEffect )
                    , layout =
                        Page.layout pageModel page
                            |> Maybe.map (Layouts.map (Main.Pages.Msg.Org_Secrets >> Page))
                            |> Maybe.map (initLayout model)
                    }
                )

        Route.Path.Org_SecretsAdd params ->
            runWhenAuthenticatedWithLayout
                model
                (\user ->
                    let
                        page : Page.Page Pages.Org_.Secrets.Add.Model Pages.Org_.Secrets.Add.Msg
                        page =
                            Pages.Org_.Secrets.Add.page user model.shared (Route.fromUrl params model.url)

                        ( pageModel, pageEffect ) =
                            Page.init page ()
                    in
                    { page =
                        Tuple.mapBoth
                            (Main.Pages.Model.Org_SecretsAdd params)
                            (Effect.map Main.Pages.Msg.Org_SecretsAdd >> fromPageEffect model)
                            ( pageModel, pageEffect )
                    , layout =
                        Page.layout pageModel page
                            |> Maybe.map (Layouts.map (Main.Pages.Msg.Org_SecretsAdd >> Page))
                            |> Maybe.map (initLayout model)
                    }
                )

        Route.Path.Org_SecretsEdit_ params ->
            runWhenAuthenticatedWithLayout
                model
                (\user ->
                    let
                        page : Page.Page Pages.Org_.Secrets.Edit_.Model Pages.Org_.Secrets.Edit_.Msg
                        page =
                            Pages.Org_.Secrets.Edit_.page user model.shared (Route.fromUrl params model.url)

                        ( pageModel, pageEffect ) =
                            Page.init page ()
                    in
                    { page =
                        Tuple.mapBoth
                            (Main.Pages.Model.Org_SecretsEdit_ params)
                            (Effect.map Main.Pages.Msg.Org_SecretsEdit_ >> fromPageEffect model)
                            ( pageModel, pageEffect )
                    , layout =
                        Page.layout pageModel page
                            |> Maybe.map (Layouts.map (Main.Pages.Msg.Org_SecretsEdit_ >> Page))
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

        Route.Path.Org_Repo_Deployments params ->
            runWhenAuthenticatedWithLayout
                model
                (\user ->
                    let
                        page : Page.Page Pages.Org_.Repo_.Deployments.Model Pages.Org_.Repo_.Deployments.Msg
                        page =
                            Pages.Org_.Repo_.Deployments.page user model.shared (Route.fromUrl params model.url)

                        ( pageModel, pageEffect ) =
                            Page.init page ()
                    in
                    { page =
                        Tuple.mapBoth
                            (Main.Pages.Model.Org_Repo_Deployments params)
                            (Effect.map Main.Pages.Msg.Org_Repo_Deployments >> fromPageEffect model)
                            ( pageModel, pageEffect )
                    , layout =
                        Page.layout pageModel page
                            |> Maybe.map (Layouts.map (Main.Pages.Msg.Org_Repo_Deployments >> Page))
                            |> Maybe.map (initLayout model)
                    }
                )

        Route.Path.Org_Repo_Schedules params ->
            runWhenAuthenticatedWithLayout
                model
                (\user ->
                    let
                        page : Page.Page Pages.Org_.Repo_.Schedules.Model Pages.Org_.Repo_.Schedules.Msg
                        page =
                            Pages.Org_.Repo_.Schedules.page user model.shared (Route.fromUrl params model.url)

                        ( pageModel, pageEffect ) =
                            Page.init page ()
                    in
                    { page =
                        Tuple.mapBoth
                            (Main.Pages.Model.Org_Repo_Schedules params)
                            (Effect.map Main.Pages.Msg.Org_Repo_Schedules >> fromPageEffect model)
                            ( pageModel, pageEffect )
                    , layout =
                        Page.layout pageModel page
                            |> Maybe.map (Layouts.map (Main.Pages.Msg.Org_Repo_Schedules >> Page))
                            |> Maybe.map (initLayout model)
                    }
                )

        Route.Path.Org_Repo_Audit params ->
            runWhenAuthenticatedWithLayout
                model
                (\user ->
                    let
                        page : Page.Page Pages.Org_.Repo_.Audit.Model Pages.Org_.Repo_.Audit.Msg
                        page =
                            Pages.Org_.Repo_.Audit.page user model.shared (Route.fromUrl params model.url)

                        ( pageModel, pageEffect ) =
                            Page.init page ()
                    in
                    { page =
                        Tuple.mapBoth
                            (Main.Pages.Model.Org_Repo_Audit params)
                            (Effect.map Main.Pages.Msg.Org_Repo_Audit >> fromPageEffect model)
                            ( pageModel, pageEffect )
                    , layout =
                        Page.layout pageModel page
                            |> Maybe.map (Layouts.map (Main.Pages.Msg.Org_Repo_Audit >> Page))
                            |> Maybe.map (initLayout model)
                    }
                )

        Route.Path.Org_Repo_Secrets params ->
            runWhenAuthenticatedWithLayout
                model
                (\user ->
                    let
                        page : Page.Page Pages.Org_.Repo_.Secrets.Model Pages.Org_.Repo_.Secrets.Msg
                        page =
                            Pages.Org_.Repo_.Secrets.page user model.shared (Route.fromUrl params model.url)

                        ( pageModel, pageEffect ) =
                            Page.init page ()
                    in
                    { page =
                        Tuple.mapBoth
                            (Main.Pages.Model.Org_Repo_Secrets params)
                            (Effect.map Main.Pages.Msg.Org_Repo_Secrets >> fromPageEffect model)
                            ( pageModel, pageEffect )
                    , layout =
                        Page.layout pageModel page
                            |> Maybe.map (Layouts.map (Main.Pages.Msg.Org_Repo_Secrets >> Page))
                            |> Maybe.map (initLayout model)
                    }
                )

        Route.Path.Org_Repo_SecretsAdd params ->
            runWhenAuthenticatedWithLayout
                model
                (\user ->
                    let
                        page : Page.Page Pages.Org_.Repo_.Secrets.Add.Model Pages.Org_.Repo_.Secrets.Add.Msg
                        page =
                            Pages.Org_.Repo_.Secrets.Add.page user model.shared (Route.fromUrl params model.url)

                        ( pageModel, pageEffect ) =
                            Page.init page ()
                    in
                    { page =
                        Tuple.mapBoth
                            (Main.Pages.Model.Org_Repo_SecretsAdd params)
                            (Effect.map Main.Pages.Msg.Org_Repo_SecretsAdd >> fromPageEffect model)
                            ( pageModel, pageEffect )
                    , layout =
                        Page.layout pageModel page
                            |> Maybe.map (Layouts.map (Main.Pages.Msg.Org_Repo_SecretsAdd >> Page))
                            |> Maybe.map (initLayout model)
                    }
                )

        Route.Path.Org_Repo_SecretsEdit_ params ->
            runWhenAuthenticatedWithLayout
                model
                (\user ->
                    let
                        page : Page.Page Pages.Org_.Repo_.Secrets.Edit_.Model Pages.Org_.Repo_.Secrets.Edit_.Msg
                        page =
                            Pages.Org_.Repo_.Secrets.Edit_.page user model.shared (Route.fromUrl params model.url)

                        ( pageModel, pageEffect ) =
                            Page.init page ()
                    in
                    { page =
                        Tuple.mapBoth
                            (Main.Pages.Model.Org_Repo_SecretsEdit_ params)
                            (Effect.map Main.Pages.Msg.Org_Repo_SecretsEdit_ >> fromPageEffect model)
                            ( pageModel, pageEffect )
                    , layout =
                        Page.layout pageModel page
                            |> Maybe.map (Layouts.map (Main.Pages.Msg.Org_Repo_SecretsEdit_ >> Page))
                            |> Maybe.map (initLayout model)
                    }
                )

        Route.Path.Org_Repo_Build_ params ->
            runWhenAuthenticatedWithLayout
                model
                (\user ->
                    let
                        page : Page.Page Pages.Org_.Repo_.Build_.Model Pages.Org_.Repo_.Build_.Msg
                        page =
                            Pages.Org_.Repo_.Build_.page user model.shared (Route.fromUrl params model.url)

                        ( pageModel, pageEffect ) =
                            Page.init page ()
                    in
                    { page =
                        Tuple.mapBoth
                            (Main.Pages.Model.Org_Repo_Build_ params)
                            (Effect.map Main.Pages.Msg.Org_Repo_Build_ >> fromPageEffect model)
                            ( pageModel, pageEffect )
                    , layout =
                        Page.layout pageModel page
                            |> Maybe.map (Layouts.map (Main.Pages.Msg.Org_Repo_Build_ >> Page))
                            |> Maybe.map (initLayout model)
                    }
                )

        Route.Path.Org_Repo_Build_Services params ->
            runWhenAuthenticatedWithLayout
                model
                (\user ->
                    let
                        page : Page.Page Pages.Org_.Repo_.Build_.Services.Model Pages.Org_.Repo_.Build_.Services.Msg
                        page =
                            Pages.Org_.Repo_.Build_.Services.page user model.shared (Route.fromUrl params model.url)

                        ( pageModel, pageEffect ) =
                            Page.init page ()
                    in
                    { page =
                        Tuple.mapBoth
                            (Main.Pages.Model.Org_Repo_Build_Services params)
                            (Effect.map Main.Pages.Msg.Org_Repo_Build_Services >> fromPageEffect model)
                            ( pageModel, pageEffect )
                    , layout =
                        Page.layout pageModel page
                            |> Maybe.map (Layouts.map (Main.Pages.Msg.Org_Repo_Build_Services >> Page))
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
                    , Maybe.Extra.unwrap Cmd.none
                        (\from -> Interop.setRedirect <| Json.Encode.string from)
                        (Dict.get "from" options.query)
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
    = NoOp
    | UrlRequested Browser.UrlRequest
    | UrlChanged Url
    | Page Main.Pages.Msg.Msg
    | Layout Main.Layouts.Msg.Msg
    | Shared Shared.Msg
    | Batch (List Msg)


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        NoOp ->
            ( model, Cmd.none )

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


updateFromPage : Main.Pages.Msg.Msg -> Model -> ( Main.Pages.Model.Model, Cmd Msg )
updateFromPage msg model =
    case ( msg, model.page ) of
        ( Main.Pages.Msg.AccountLogin pageMsg, Main.Pages.Model.AccountLogin pageModel ) ->
            Tuple.mapBoth
                Main.Pages.Model.AccountLogin
                (Effect.map Main.Pages.Msg.AccountLogin >> fromPageEffect model)
                (Page.update (Pages.Account.Login.page model.shared (Route.fromUrl () model.url)) pageMsg pageModel)

        ( Main.Pages.Msg.AccountSettings pageMsg, Main.Pages.Model.AccountSettings pageModel ) ->
            runWhenAuthenticated
                model
                (\user ->
                    Tuple.mapBoth
                        Main.Pages.Model.AccountSettings
                        (Effect.map Main.Pages.Msg.AccountSettings >> fromPageEffect model)
                        (Page.update (Pages.Account.Settings.page user model.shared (Route.fromUrl () model.url)) pageMsg pageModel)
                )

        ( Main.Pages.Msg.AccountSourceRepos pageMsg, Main.Pages.Model.AccountSourceRepos pageModel ) ->
            runWhenAuthenticated
                model
                (\user ->
                    Tuple.mapBoth
                        Main.Pages.Model.AccountSourceRepos
                        (Effect.map Main.Pages.Msg.AccountSourceRepos >> fromPageEffect model)
                        (Page.update (Pages.Account.SourceRepos.page user model.shared (Route.fromUrl () model.url)) pageMsg pageModel)
                )

        ( Main.Pages.Msg.Home pageMsg, Main.Pages.Model.Home pageModel ) ->
            runWhenAuthenticated
                model
                (\user ->
                    Tuple.mapBoth
                        Main.Pages.Model.Home
                        (Effect.map Main.Pages.Msg.Home >> fromPageEffect model)
                        (Page.update (Pages.Home.page user model.shared (Route.fromUrl () model.url)) pageMsg pageModel)
                )

        ( Main.Pages.Msg.Org_ pageMsg, Main.Pages.Model.Org_ params pageModel ) ->
            runWhenAuthenticated
                model
                (\user ->
                    Tuple.mapBoth
                        (Main.Pages.Model.Org_ params)
                        (Effect.map Main.Pages.Msg.Org_ >> fromPageEffect model)
                        (Page.update (Pages.Org_.page user model.shared (Route.fromUrl params model.url)) pageMsg pageModel)
                )

        ( Main.Pages.Msg.Org_Builds pageMsg, Main.Pages.Model.Org_Builds params pageModel ) ->
            runWhenAuthenticated
                model
                (\user ->
                    Tuple.mapBoth
                        (Main.Pages.Model.Org_Builds params)
                        (Effect.map Main.Pages.Msg.Org_Builds >> fromPageEffect model)
                        (Page.update (Pages.Org_.Builds.page user model.shared (Route.fromUrl params model.url)) pageMsg pageModel)
                )

        ( Main.Pages.Msg.Org_Secrets pageMsg, Main.Pages.Model.Org_Secrets params pageModel ) ->
            runWhenAuthenticated
                model
                (\user ->
                    Tuple.mapBoth
                        (Main.Pages.Model.Org_Secrets params)
                        (Effect.map Main.Pages.Msg.Org_Secrets >> fromPageEffect model)
                        (Page.update (Pages.Org_.Secrets.page user model.shared (Route.fromUrl params model.url)) pageMsg pageModel)
                )

        ( Main.Pages.Msg.Org_SecretsAdd pageMsg, Main.Pages.Model.Org_SecretsAdd params pageModel ) ->
            runWhenAuthenticated
                model
                (\user ->
                    Tuple.mapBoth
                        (Main.Pages.Model.Org_SecretsAdd params)
                        (Effect.map Main.Pages.Msg.Org_SecretsAdd >> fromPageEffect model)
                        (Page.update (Pages.Org_.Secrets.Add.page user model.shared (Route.fromUrl params model.url)) pageMsg pageModel)
                )

        ( Main.Pages.Msg.Org_SecretsEdit_ pageMsg, Main.Pages.Model.Org_SecretsEdit_ params pageModel ) ->
            runWhenAuthenticated
                model
                (\user ->
                    Tuple.mapBoth
                        (Main.Pages.Model.Org_SecretsEdit_ params)
                        (Effect.map Main.Pages.Msg.Org_SecretsEdit_ >> fromPageEffect model)
                        (Page.update (Pages.Org_.Secrets.Edit_.page user model.shared (Route.fromUrl params model.url)) pageMsg pageModel)
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

        ( Main.Pages.Msg.Org_Repo_Deployments pageMsg, Main.Pages.Model.Org_Repo_Deployments params pageModel ) ->
            runWhenAuthenticated
                model
                (\user ->
                    Tuple.mapBoth
                        (Main.Pages.Model.Org_Repo_Deployments params)
                        (Effect.map Main.Pages.Msg.Org_Repo_Deployments >> fromPageEffect model)
                        (Page.update (Pages.Org_.Repo_.Deployments.page user model.shared (Route.fromUrl params model.url)) pageMsg pageModel)
                )

        ( Main.Pages.Msg.Org_Repo_Schedules pageMsg, Main.Pages.Model.Org_Repo_Schedules params pageModel ) ->
            runWhenAuthenticated
                model
                (\user ->
                    Tuple.mapBoth
                        (Main.Pages.Model.Org_Repo_Schedules params)
                        (Effect.map Main.Pages.Msg.Org_Repo_Schedules >> fromPageEffect model)
                        (Page.update (Pages.Org_.Repo_.Schedules.page user model.shared (Route.fromUrl params model.url)) pageMsg pageModel)
                )

        ( Main.Pages.Msg.Org_Repo_Audit pageMsg, Main.Pages.Model.Org_Repo_Audit params pageModel ) ->
            runWhenAuthenticated
                model
                (\user ->
                    Tuple.mapBoth
                        (Main.Pages.Model.Org_Repo_Audit params)
                        (Effect.map Main.Pages.Msg.Org_Repo_Audit >> fromPageEffect model)
                        (Page.update (Pages.Org_.Repo_.Audit.page user model.shared (Route.fromUrl params model.url)) pageMsg pageModel)
                )

        ( Main.Pages.Msg.Org_Repo_Secrets pageMsg, Main.Pages.Model.Org_Repo_Secrets params pageModel ) ->
            runWhenAuthenticated
                model
                (\user ->
                    Tuple.mapBoth
                        (Main.Pages.Model.Org_Repo_Secrets params)
                        (Effect.map Main.Pages.Msg.Org_Repo_Secrets >> fromPageEffect model)
                        (Page.update (Pages.Org_.Repo_.Secrets.page user model.shared (Route.fromUrl params model.url)) pageMsg pageModel)
                )

        ( Main.Pages.Msg.Org_Repo_SecretsAdd pageMsg, Main.Pages.Model.Org_Repo_SecretsAdd params pageModel ) ->
            runWhenAuthenticated
                model
                (\user ->
                    Tuple.mapBoth
                        (Main.Pages.Model.Org_Repo_SecretsAdd params)
                        (Effect.map Main.Pages.Msg.Org_Repo_SecretsAdd >> fromPageEffect model)
                        (Page.update (Pages.Org_.Repo_.Secrets.Add.page user model.shared (Route.fromUrl params model.url)) pageMsg pageModel)
                )

        ( Main.Pages.Msg.Org_Repo_SecretsEdit_ pageMsg, Main.Pages.Model.Org_Repo_SecretsEdit_ params pageModel ) ->
            runWhenAuthenticated
                model
                (\user ->
                    Tuple.mapBoth
                        (Main.Pages.Model.Org_Repo_SecretsEdit_ params)
                        (Effect.map Main.Pages.Msg.Org_Repo_SecretsEdit_ >> fromPageEffect model)
                        (Page.update (Pages.Org_.Repo_.Secrets.Edit_.page user model.shared (Route.fromUrl params model.url)) pageMsg pageModel)
                )

        ( Main.Pages.Msg.Org_Repo_Build_ pageMsg, Main.Pages.Model.Org_Repo_Build_ params pageModel ) ->
            runWhenAuthenticated
                model
                (\user ->
                    Tuple.mapBoth
                        (Main.Pages.Model.Org_Repo_Build_ params)
                        (Effect.map Main.Pages.Msg.Org_Repo_Build_ >> fromPageEffect model)
                        (Page.update (Pages.Org_.Repo_.Build_.page user model.shared (Route.fromUrl params model.url)) pageMsg pageModel)
                )

        ( Main.Pages.Msg.Org_Repo_Build_Services pageMsg, Main.Pages.Model.Org_Repo_Build_Services params pageModel ) ->
            runWhenAuthenticated
                model
                (\user ->
                    Tuple.mapBoth
                        (Main.Pages.Model.Org_Repo_Build_Services params)
                        (Effect.map Main.Pages.Msg.Org_Repo_Build_Services >> fromPageEffect model)
                        (Page.update (Pages.Org_.Repo_.Build_.Services.page user model.shared (Route.fromUrl params model.url)) pageMsg pageModel)
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

        ( Just (Layouts.Default_Build props), Just (Main.Layouts.Model.Default_Build layoutModel), Main.Layouts.Msg.Default layoutMsg ) ->
            let
                defaultProps =
                    Layouts.Default.Build.layout props model.shared route
                        |> Layout.parentProps
            in
            Tuple.mapBoth
                (\newModel -> Just (Main.Layouts.Model.Default_Build { layoutModel | default = newModel }))
                (Effect.map Main.Layouts.Msg.Default >> fromLayoutEffect model)
                (Layout.update (Layouts.Default.layout defaultProps model.shared route) layoutMsg layoutModel.default)

        ( Just (Layouts.Default_Build props), Just (Main.Layouts.Model.Default_Build layoutModel), Main.Layouts.Msg.Default_Build layoutMsg ) ->
            Tuple.mapBoth
                (\newModel -> Just (Main.Layouts.Model.Default_Build { layoutModel | repo = newModel }))
                (Effect.map Main.Layouts.Msg.Default_Build >> fromLayoutEffect model)
                (Layout.update (Layouts.Default.Build.layout props model.shared route) layoutMsg layoutModel.repo)

        _ ->
            ( model.layout
            , Cmd.none
            )


toLayoutFromPage : Model -> Maybe (Layouts.Layout Msg)
toLayoutFromPage model =
    case model.page of
        Main.Pages.Model.AccountLogin pageModel ->
            Route.fromUrl () model.url
                |> Pages.Account.Login.page model.shared
                |> Page.layout pageModel
                |> Maybe.map (Layouts.map (Main.Pages.Msg.AccountLogin >> Page))

        Main.Pages.Model.AccountSettings pageModel ->
            Route.fromUrl () model.url
                |> toAuthProtectedPage model Pages.Account.Settings.page
                |> Maybe.andThen (Page.layout pageModel)
                |> Maybe.map (Layouts.map (Main.Pages.Msg.AccountSettings >> Page))

        Main.Pages.Model.AccountSourceRepos pageModel ->
            Route.fromUrl () model.url
                |> toAuthProtectedPage model Pages.Account.SourceRepos.page
                |> Maybe.andThen (Page.layout pageModel)
                |> Maybe.map (Layouts.map (Main.Pages.Msg.AccountSourceRepos >> Page))

        Main.Pages.Model.Home pageModel ->
            Route.fromUrl () model.url
                |> toAuthProtectedPage model Pages.Home.page
                |> Maybe.andThen (Page.layout pageModel)
                |> Maybe.map (Layouts.map (Main.Pages.Msg.Home >> Page))

        Main.Pages.Model.Org_ params pageModel ->
            Route.fromUrl params model.url
                |> toAuthProtectedPage model Pages.Org_.page
                |> Maybe.andThen (Page.layout pageModel)
                |> Maybe.map (Layouts.map (Main.Pages.Msg.Org_ >> Page))

        Main.Pages.Model.Org_Builds params pageModel ->
            Route.fromUrl params model.url
                |> toAuthProtectedPage model Pages.Org_.Builds.page
                |> Maybe.andThen (Page.layout pageModel)
                |> Maybe.map (Layouts.map (Main.Pages.Msg.Org_Builds >> Page))

        Main.Pages.Model.Org_Secrets params pageModel ->
            Route.fromUrl params model.url
                |> toAuthProtectedPage model Pages.Org_.Secrets.page
                |> Maybe.andThen (Page.layout pageModel)
                |> Maybe.map (Layouts.map (Main.Pages.Msg.Org_Secrets >> Page))

        Main.Pages.Model.Org_SecretsAdd params pageModel ->
            Route.fromUrl params model.url
                |> toAuthProtectedPage model Pages.Org_.Secrets.Add.page
                |> Maybe.andThen (Page.layout pageModel)
                |> Maybe.map (Layouts.map (Main.Pages.Msg.Org_SecretsAdd >> Page))

        Main.Pages.Model.Org_SecretsEdit_ params pageModel ->
            Route.fromUrl params model.url
                |> toAuthProtectedPage model Pages.Org_.Secrets.Edit_.page
                |> Maybe.andThen (Page.layout pageModel)
                |> Maybe.map (Layouts.map (Main.Pages.Msg.Org_SecretsEdit_ >> Page))

        Main.Pages.Model.Org_Repo_ params pageModel ->
            Route.fromUrl params model.url
                |> toAuthProtectedPage model Pages.Org_.Repo_.page
                |> Maybe.andThen (Page.layout pageModel)
                |> Maybe.map (Layouts.map (Main.Pages.Msg.Org_Repo_ >> Page))

        Main.Pages.Model.Org_Repo_Deployments params pageModel ->
            Route.fromUrl params model.url
                |> toAuthProtectedPage model Pages.Org_.Repo_.Deployments.page
                |> Maybe.andThen (Page.layout pageModel)
                |> Maybe.map (Layouts.map (Main.Pages.Msg.Org_Repo_Deployments >> Page))

        Main.Pages.Model.Org_Repo_Schedules params pageModel ->
            Route.fromUrl params model.url
                |> toAuthProtectedPage model Pages.Org_.Repo_.Schedules.page
                |> Maybe.andThen (Page.layout pageModel)
                |> Maybe.map (Layouts.map (Main.Pages.Msg.Org_Repo_Schedules >> Page))

        Main.Pages.Model.Org_Repo_Audit params pageModel ->
            Route.fromUrl params model.url
                |> toAuthProtectedPage model Pages.Org_.Repo_.Audit.page
                |> Maybe.andThen (Page.layout pageModel)
                |> Maybe.map (Layouts.map (Main.Pages.Msg.Org_Repo_Audit >> Page))

        Main.Pages.Model.Org_Repo_Secrets params pageModel ->
            Route.fromUrl params model.url
                |> toAuthProtectedPage model Pages.Org_.Repo_.Secrets.page
                |> Maybe.andThen (Page.layout pageModel)
                |> Maybe.map (Layouts.map (Main.Pages.Msg.Org_Repo_Secrets >> Page))

        Main.Pages.Model.Org_Repo_SecretsAdd params pageModel ->
            Route.fromUrl params model.url
                |> toAuthProtectedPage model Pages.Org_.Repo_.Secrets.Add.page
                |> Maybe.andThen (Page.layout pageModel)
                |> Maybe.map (Layouts.map (Main.Pages.Msg.Org_Repo_SecretsAdd >> Page))

        Main.Pages.Model.Org_Repo_SecretsEdit_ params pageModel ->
            Route.fromUrl params model.url
                |> toAuthProtectedPage model Pages.Org_.Repo_.Secrets.Edit_.page
                |> Maybe.andThen (Page.layout pageModel)
                |> Maybe.map (Layouts.map (Main.Pages.Msg.Org_Repo_SecretsEdit_ >> Page))

        Main.Pages.Model.Org_Repo_Build_ params pageModel ->
            Route.fromUrl params model.url
                |> toAuthProtectedPage model Pages.Org_.Repo_.Build_.page
                |> Maybe.andThen (Page.layout pageModel)
                |> Maybe.map (Layouts.map (Main.Pages.Msg.Org_Repo_Build_ >> Page))

        Main.Pages.Model.Org_Repo_Build_Services params pageModel ->
            Route.fromUrl params model.url
                |> toAuthProtectedPage model Pages.Org_.Repo_.Build_.Services.page
                |> Maybe.andThen (Page.layout pageModel)
                |> Maybe.map (Layouts.map (Main.Pages.Msg.Org_Repo_Build_Services >> Page))

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
                Main.Pages.Model.AccountLogin pageModel ->
                    Page.subscriptions (Pages.Account.Login.page model.shared (Route.fromUrl () model.url)) pageModel
                        |> Sub.map Main.Pages.Msg.AccountLogin
                        |> Sub.map Page

                Main.Pages.Model.AccountSettings pageModel ->
                    Sub.none

                Main.Pages.Model.AccountSourceRepos pageModel ->
                    Sub.none

                Main.Pages.Model.Home pageModel ->
                    Sub.none

                Main.Pages.Model.Org_ params pageModel ->
                    Auth.Action.subscriptions
                        (\user ->
                            Page.subscriptions (Pages.Org_.page user model.shared (Route.fromUrl params model.url)) pageModel
                                |> Sub.map Main.Pages.Msg.Org_
                                |> Sub.map Page
                        )
                        (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

                Main.Pages.Model.Org_Builds params pageModel ->
                    Auth.Action.subscriptions
                        (\user ->
                            Page.subscriptions (Pages.Org_.Builds.page user model.shared (Route.fromUrl params model.url)) pageModel
                                |> Sub.map Main.Pages.Msg.Org_Builds
                                |> Sub.map Page
                        )
                        (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

                Main.Pages.Model.Org_Secrets params pageModel ->
                    Auth.Action.subscriptions
                        (\user ->
                            Page.subscriptions (Pages.Org_.Secrets.page user model.shared (Route.fromUrl params model.url)) pageModel
                                |> Sub.map Main.Pages.Msg.Org_Secrets
                                |> Sub.map Page
                        )
                        (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

                Main.Pages.Model.Org_SecretsAdd params pageModel ->
                    Auth.Action.subscriptions
                        (\user ->
                            Page.subscriptions (Pages.Org_.Secrets.Add.page user model.shared (Route.fromUrl params model.url)) pageModel
                                |> Sub.map Main.Pages.Msg.Org_SecretsAdd
                                |> Sub.map Page
                        )
                        (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

                Main.Pages.Model.Org_SecretsEdit_ params pageModel ->
                    Auth.Action.subscriptions
                        (\user ->
                            Page.subscriptions (Pages.Org_.Secrets.Edit_.page user model.shared (Route.fromUrl params model.url)) pageModel
                                |> Sub.map Main.Pages.Msg.Org_SecretsEdit_
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

                Main.Pages.Model.Org_Repo_Deployments params pageModel ->
                    Auth.Action.subscriptions
                        (\user ->
                            Page.subscriptions (Pages.Org_.Repo_.Deployments.page user model.shared (Route.fromUrl params model.url)) pageModel
                                |> Sub.map Main.Pages.Msg.Org_Repo_Deployments
                                |> Sub.map Page
                        )
                        (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

                Main.Pages.Model.Org_Repo_Schedules params pageModel ->
                    Auth.Action.subscriptions
                        (\user ->
                            Page.subscriptions (Pages.Org_.Repo_.Schedules.page user model.shared (Route.fromUrl params model.url)) pageModel
                                |> Sub.map Main.Pages.Msg.Org_Repo_Schedules
                                |> Sub.map Page
                        )
                        (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

                Main.Pages.Model.Org_Repo_Audit params pageModel ->
                    Auth.Action.subscriptions
                        (\user ->
                            Page.subscriptions (Pages.Org_.Repo_.Audit.page user model.shared (Route.fromUrl params model.url)) pageModel
                                |> Sub.map Main.Pages.Msg.Org_Repo_Audit
                                |> Sub.map Page
                        )
                        (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

                Main.Pages.Model.Org_Repo_Secrets params pageModel ->
                    Auth.Action.subscriptions
                        (\user ->
                            Page.subscriptions (Pages.Org_.Repo_.Secrets.page user model.shared (Route.fromUrl params model.url)) pageModel
                                |> Sub.map Main.Pages.Msg.Org_Repo_Secrets
                                |> Sub.map Page
                        )
                        (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

                Main.Pages.Model.Org_Repo_SecretsAdd params pageModel ->
                    Auth.Action.subscriptions
                        (\user ->
                            Page.subscriptions (Pages.Org_.Repo_.Secrets.Add.page user model.shared (Route.fromUrl params model.url)) pageModel
                                |> Sub.map Main.Pages.Msg.Org_Repo_SecretsAdd
                                |> Sub.map Page
                        )
                        (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

                Main.Pages.Model.Org_Repo_SecretsEdit_ params pageModel ->
                    Auth.Action.subscriptions
                        (\user ->
                            Page.subscriptions (Pages.Org_.Repo_.Secrets.Edit_.page user model.shared (Route.fromUrl params model.url)) pageModel
                                |> Sub.map Main.Pages.Msg.Org_Repo_SecretsEdit_
                                |> Sub.map Page
                        )
                        (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

                Main.Pages.Model.Org_Repo_Build_ params pageModel ->
                    Auth.Action.subscriptions
                        (\user ->
                            Page.subscriptions (Pages.Org_.Repo_.Build_.page user model.shared (Route.fromUrl params model.url)) pageModel
                                |> Sub.map Main.Pages.Msg.Org_Repo_Build_
                                |> Sub.map Page
                        )
                        (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

                Main.Pages.Model.Org_Repo_Build_Services params pageModel ->
                    Auth.Action.subscriptions
                        (\user ->
                            Page.subscriptions (Pages.Org_.Repo_.Build_.Services.page user model.shared (Route.fromUrl params model.url)) pageModel
                                |> Sub.map Main.Pages.Msg.Org_Repo_Build_Services
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

                ( Just (Layouts.Default_Build props), Just (Main.Layouts.Model.Default_Build layoutModel) ) ->
                    let
                        defaultProps =
                            Layouts.Default.Build.layout props model.shared route
                                |> Layout.parentProps
                    in
                    Sub.batch
                        [ Layout.subscriptions (Layouts.Default.layout defaultProps model.shared route) layoutModel.default
                            |> Sub.map Main.Layouts.Msg.Default
                            |> Sub.map Layout
                        , Layout.subscriptions (Layouts.Default.Build.layout props model.shared route) layoutModel.repo
                            |> Sub.map Main.Layouts.Msg.Default_Build
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

        ( Just (Layouts.Default_Build props), Just (Main.Layouts.Model.Default_Build layoutModel) ) ->
            let
                defaultProps =
                    Layouts.Default.Build.layout props model.shared route
                        |> Layout.parentProps
            in
            Layout.view
                (Layouts.Default.layout defaultProps model.shared route)
                { model = layoutModel.default
                , toContentMsg = Main.Layouts.Msg.Default >> Layout
                , content =
                    Layout.view
                        (Layouts.Default.Build.layout props model.shared route)
                        { model = layoutModel.repo
                        , toContentMsg = Main.Layouts.Msg.Default_Build >> Layout
                        , content = viewPage model
                        }
                }

        _ ->
            viewPage model


viewPage : Model -> View Msg
viewPage model =
    case model.page of
        Main.Pages.Model.AccountLogin pageModel ->
            Page.view (Pages.Account.Login.page model.shared (Route.fromUrl () model.url)) pageModel
                |> View.map Main.Pages.Msg.AccountLogin
                |> View.map Page

        Main.Pages.Model.AccountSettings pageModel ->
            Auth.Action.view
                (\user ->
                    Page.view (Pages.Account.Settings.page user model.shared (Route.fromUrl () model.url)) pageModel
                        |> View.map Main.Pages.Msg.AccountSettings
                        |> View.map Page
                )
                (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

        Main.Pages.Model.AccountSourceRepos pageModel ->
            Auth.Action.view
                (\user ->
                    Page.view (Pages.Account.SourceRepos.page user model.shared (Route.fromUrl () model.url)) pageModel
                        |> View.map Main.Pages.Msg.AccountSourceRepos
                        |> View.map Page
                )
                (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

        Main.Pages.Model.Home pageModel ->
            Auth.Action.view
                (\user ->
                    Page.view (Pages.Home.page user model.shared (Route.fromUrl () model.url)) pageModel
                        |> View.map Main.Pages.Msg.Home
                        |> View.map Page
                )
                (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

        Main.Pages.Model.Org_ params pageModel ->
            Auth.Action.view
                (\user ->
                    Page.view (Pages.Org_.page user model.shared (Route.fromUrl params model.url)) pageModel
                        |> View.map Main.Pages.Msg.Org_
                        |> View.map Page
                )
                (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

        Main.Pages.Model.Org_Builds params pageModel ->
            Auth.Action.view
                (\user ->
                    Page.view (Pages.Org_.Builds.page user model.shared (Route.fromUrl params model.url)) pageModel
                        |> View.map Main.Pages.Msg.Org_Builds
                        |> View.map Page
                )
                (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

        Main.Pages.Model.Org_Secrets params pageModel ->
            Auth.Action.view
                (\user ->
                    Page.view (Pages.Org_.Secrets.page user model.shared (Route.fromUrl params model.url)) pageModel
                        |> View.map Main.Pages.Msg.Org_Secrets
                        |> View.map Page
                )
                (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

        Main.Pages.Model.Org_SecretsAdd params pageModel ->
            Auth.Action.view
                (\user ->
                    Page.view (Pages.Org_.Secrets.Add.page user model.shared (Route.fromUrl params model.url)) pageModel
                        |> View.map Main.Pages.Msg.Org_SecretsAdd
                        |> View.map Page
                )
                (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

        Main.Pages.Model.Org_SecretsEdit_ params pageModel ->
            Auth.Action.view
                (\user ->
                    Page.view (Pages.Org_.Secrets.Edit_.page user model.shared (Route.fromUrl params model.url)) pageModel
                        |> View.map Main.Pages.Msg.Org_SecretsEdit_
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

        Main.Pages.Model.Org_Repo_Deployments params pageModel ->
            Auth.Action.view
                (\user ->
                    Page.view (Pages.Org_.Repo_.Deployments.page user model.shared (Route.fromUrl params model.url)) pageModel
                        |> View.map Main.Pages.Msg.Org_Repo_Deployments
                        |> View.map Page
                )
                (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

        Main.Pages.Model.Org_Repo_Schedules params pageModel ->
            Auth.Action.view
                (\user ->
                    Page.view (Pages.Org_.Repo_.Schedules.page user model.shared (Route.fromUrl params model.url)) pageModel
                        |> View.map Main.Pages.Msg.Org_Repo_Schedules
                        |> View.map Page
                )
                (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

        Main.Pages.Model.Org_Repo_Audit params pageModel ->
            Auth.Action.view
                (\user ->
                    Page.view (Pages.Org_.Repo_.Audit.page user model.shared (Route.fromUrl params model.url)) pageModel
                        |> View.map Main.Pages.Msg.Org_Repo_Audit
                        |> View.map Page
                )
                (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

        Main.Pages.Model.Org_Repo_Secrets params pageModel ->
            Auth.Action.view
                (\user ->
                    Page.view (Pages.Org_.Repo_.Secrets.page user model.shared (Route.fromUrl params model.url)) pageModel
                        |> View.map Main.Pages.Msg.Org_Repo_Secrets
                        |> View.map Page
                )
                (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

        Main.Pages.Model.Org_Repo_SecretsAdd params pageModel ->
            Auth.Action.view
                (\user ->
                    Page.view (Pages.Org_.Repo_.Secrets.Add.page user model.shared (Route.fromUrl params model.url)) pageModel
                        |> View.map Main.Pages.Msg.Org_Repo_SecretsAdd
                        |> View.map Page
                )
                (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

        Main.Pages.Model.Org_Repo_SecretsEdit_ params pageModel ->
            Auth.Action.view
                (\user ->
                    Page.view (Pages.Org_.Repo_.Secrets.Edit_.page user model.shared (Route.fromUrl params model.url)) pageModel
                        |> View.map Main.Pages.Msg.Org_Repo_SecretsEdit_
                        |> View.map Page
                )
                (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

        Main.Pages.Model.Org_Repo_Build_ params pageModel ->
            Auth.Action.view
                (\user ->
                    Page.view (Pages.Org_.Repo_.Build_.page user model.shared (Route.fromUrl params model.url)) pageModel
                        |> View.map Main.Pages.Msg.Org_Repo_Build_
                        |> View.map Page
                )
                (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

        Main.Pages.Model.Org_Repo_Build_Services params pageModel ->
            Auth.Action.view
                (\user ->
                    Page.view (Pages.Org_.Repo_.Build_.Services.page user model.shared (Route.fromUrl params model.url)) pageModel
                        |> View.map Main.Pages.Msg.Org_Repo_Build_Services
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
        Main.Pages.Model.AccountLogin pageModel ->
            Page.toUrlMessages routes (Pages.Account.Login.page model.shared (Route.fromUrl () model.url))
                |> List.map Main.Pages.Msg.AccountLogin
                |> List.map Page
                |> toCommands

        Main.Pages.Model.AccountSettings pageModel ->
            Auth.Action.command
                (\user ->
                    Page.toUrlMessages routes (Pages.Account.Settings.page user model.shared (Route.fromUrl () model.url))
                        |> List.map Main.Pages.Msg.AccountSettings
                        |> List.map Page
                        |> toCommands
                )
                (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

        Main.Pages.Model.AccountSourceRepos pageModel ->
            Auth.Action.command
                (\user ->
                    Page.toUrlMessages routes (Pages.Account.SourceRepos.page user model.shared (Route.fromUrl () model.url))
                        |> List.map Main.Pages.Msg.AccountSourceRepos
                        |> List.map Page
                        |> toCommands
                )
                (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

        Main.Pages.Model.Home pageModel ->
            Auth.Action.command
                (\user ->
                    Page.toUrlMessages routes (Pages.Home.page user model.shared (Route.fromUrl () model.url))
                        |> List.map Main.Pages.Msg.Home
                        |> List.map Page
                        |> toCommands
                )
                (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

        Main.Pages.Model.Org_ params pageModel ->
            Auth.Action.command
                (\user ->
                    Page.toUrlMessages routes (Pages.Org_.page user model.shared (Route.fromUrl params model.url))
                        |> List.map Main.Pages.Msg.Org_
                        |> List.map Page
                        |> toCommands
                )
                (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

        Main.Pages.Model.Org_Builds params pageModel ->
            Auth.Action.command
                (\user ->
                    Page.toUrlMessages routes (Pages.Org_.Builds.page user model.shared (Route.fromUrl params model.url))
                        |> List.map Main.Pages.Msg.Org_Builds
                        |> List.map Page
                        |> toCommands
                )
                (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

        Main.Pages.Model.Org_Secrets params pageModel ->
            Auth.Action.command
                (\user ->
                    Page.toUrlMessages routes (Pages.Org_.Secrets.page user model.shared (Route.fromUrl params model.url))
                        |> List.map Main.Pages.Msg.Org_Secrets
                        |> List.map Page
                        |> toCommands
                )
                (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

        Main.Pages.Model.Org_SecretsAdd params pageModel ->
            Auth.Action.command
                (\user ->
                    Page.toUrlMessages routes (Pages.Org_.Secrets.Add.page user model.shared (Route.fromUrl params model.url))
                        |> List.map Main.Pages.Msg.Org_SecretsAdd
                        |> List.map Page
                        |> toCommands
                )
                (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

        Main.Pages.Model.Org_SecretsEdit_ params pageModel ->
            Auth.Action.command
                (\user ->
                    Page.toUrlMessages routes (Pages.Org_.Secrets.Edit_.page user model.shared (Route.fromUrl params model.url))
                        |> List.map Main.Pages.Msg.Org_SecretsEdit_
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

        Main.Pages.Model.Org_Repo_Deployments params pageModel ->
            Auth.Action.command
                (\user ->
                    Page.toUrlMessages routes (Pages.Org_.Repo_.Deployments.page user model.shared (Route.fromUrl params model.url))
                        |> List.map Main.Pages.Msg.Org_Repo_Deployments
                        |> List.map Page
                        |> toCommands
                )
                (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

        Main.Pages.Model.Org_Repo_Schedules params pageModel ->
            Auth.Action.command
                (\user ->
                    Page.toUrlMessages routes (Pages.Org_.Repo_.Schedules.page user model.shared (Route.fromUrl params model.url))
                        |> List.map Main.Pages.Msg.Org_Repo_Schedules
                        |> List.map Page
                        |> toCommands
                )
                (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

        Main.Pages.Model.Org_Repo_Audit params pageModel ->
            Auth.Action.command
                (\user ->
                    Page.toUrlMessages routes (Pages.Org_.Repo_.Audit.page user model.shared (Route.fromUrl params model.url))
                        |> List.map Main.Pages.Msg.Org_Repo_Audit
                        |> List.map Page
                        |> toCommands
                )
                (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

        Main.Pages.Model.Org_Repo_Secrets params pageModel ->
            Auth.Action.command
                (\user ->
                    Page.toUrlMessages routes (Pages.Org_.Repo_.Secrets.page user model.shared (Route.fromUrl params model.url))
                        |> List.map Main.Pages.Msg.Org_Repo_Secrets
                        |> List.map Page
                        |> toCommands
                )
                (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

        Main.Pages.Model.Org_Repo_SecretsAdd params pageModel ->
            Auth.Action.command
                (\user ->
                    Page.toUrlMessages routes (Pages.Org_.Repo_.Secrets.Add.page user model.shared (Route.fromUrl params model.url))
                        |> List.map Main.Pages.Msg.Org_Repo_SecretsAdd
                        |> List.map Page
                        |> toCommands
                )
                (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

        Main.Pages.Model.Org_Repo_SecretsEdit_ params pageModel ->
            Auth.Action.command
                (\user ->
                    Page.toUrlMessages routes (Pages.Org_.Repo_.Secrets.Edit_.page user model.shared (Route.fromUrl params model.url))
                        |> List.map Main.Pages.Msg.Org_Repo_SecretsEdit_
                        |> List.map Page
                        |> toCommands
                )
                (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

        Main.Pages.Model.Org_Repo_Build_ params pageModel ->
            Auth.Action.command
                (\user ->
                    Page.toUrlMessages routes (Pages.Org_.Repo_.Build_.page user model.shared (Route.fromUrl params model.url))
                        |> List.map Main.Pages.Msg.Org_Repo_Build_
                        |> List.map Page
                        |> toCommands
                )
                (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

        Main.Pages.Model.Org_Repo_Build_Services params pageModel ->
            Auth.Action.command
                (\user ->
                    Page.toUrlMessages routes (Pages.Org_.Repo_.Build_.Services.page user model.shared (Route.fromUrl params model.url))
                        |> List.map Main.Pages.Msg.Org_Repo_Build_Services
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

        ( Just (Layouts.Default_Build props), Just (Main.Layouts.Model.Default_Build layoutModel) ) ->
            let
                defaultProps =
                    Layouts.Default.Build.layout props model.shared route
                        |> Layout.parentProps
            in
            Cmd.batch
                [ Layout.toUrlMessages routes (Layouts.Default.layout defaultProps model.shared route)
                    |> List.map Main.Layouts.Msg.Default
                    |> List.map Layout
                    |> toCommands
                , Layout.toUrlMessages routes (Layouts.Default.Build.layout props model.shared route)
                    |> List.map Main.Layouts.Msg.Default_Build
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

                Just ( Layouts.Default_Build _, Layouts.Default_Build _ ) ->
                    True

                Just ( Layouts.Default_Build _, Layouts.Default _ ) ->
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
        Route.Path.AccountLogin ->
            False

        Route.Path.AccountLogout ->
            True

        Route.Path.AccountAuthenticate_ ->
            False

        Route.Path.AccountSettings ->
            True

        Route.Path.AccountSourceRepos ->
            True

        Route.Path.Home ->
            True

        Route.Path.Org_ _ ->
            True

        Route.Path.Org_Builds _ ->
            True

        Route.Path.Org_Secrets _ ->
            True

        Route.Path.Org_SecretsAdd _ ->
            True

        Route.Path.Org_SecretsEdit_ _ ->
            True

        Route.Path.Org_Repo_ _ ->
            True

        Route.Path.Org_Repo_Deployments _ ->
            True

        Route.Path.Org_Repo_Schedules _ ->
            True

        Route.Path.Org_Repo_Audit _ ->
            True

        Route.Path.Org_Repo_Secrets _ ->
            True

        Route.Path.Org_Repo_SecretsAdd _ ->
            True

        Route.Path.Org_Repo_SecretsEdit_ _ ->
            True

        Route.Path.Org_Repo_Build_ _ ->
            True

        Route.Path.Org_Repo_Build_Services _ ->
            True

        Route.Path.NotFound_ ->
            False
