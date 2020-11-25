module Msg exposing (Interval(..), Msg(..), RefreshData)

import Alerts exposing (Alert(..))
import Api.Pagination as Pagination
import Browser exposing (Document, UrlRequest)
import Browser.Dom as Dom
import Browser.Events exposing (Visibility(..))
import Errors exposing (Error)
import Http
import Http.Detailed
import Pages.Build.Model
import Pages.Pipeline.Model
import Pages.Secrets.Model
import Routes
import Time exposing (Posix, Zone)
import Toasty as Alerting
import Vela
    exposing
        ( Build
        , BuildNumber
        , Builds
        , CurrentUser
        , Engine
        , Event
        , Field
        , FocusFragment
        , Hooks
        , Log
        , Org
        , Repo
        , Repositories
        , Repository
        , Secret
        , Secrets
        , Session
        , SourceRepositories
        , Step
        , StepNumber
        , Steps
        , Theme
        , Type
        , User
        )


type Interval
    = OneSecond
    | OneSecondHidden
    | FiveSecond RefreshData
    | FiveSecondHidden RefreshData


type alias RefreshData =
    { org : Org
    , repo : Repo
    , build_number : Maybe BuildNumber
    , steps : Maybe Steps
    }


type Msg
    = NoOp
      -- User events
    | NewRoute Routes.Route
    | ClickedLink UrlRequest
    | SearchSourceRepos Org String
    | SearchFavorites String
    | ChangeRepoTimeout String
    | RefreshSettings Org Repo
    | RefreshHooks Org Repo
    | RefreshSecrets Engine Type Org Repo
    | SetTheme Theme
    | GotoPage Pagination.Page
    | ShowHideHelp (Maybe Bool)
    | ShowHideIdentity (Maybe Bool)
    | Copy String
      -- Outgoing HTTP requests
    | SignInRequested
    | FetchSourceRepositories
    | ToggleFavorite Org (Maybe Repo)
    | EnableRepo Repository
    | UpdateRepoEvent Org Repo Field Bool
    | UpdateRepoAccess Org Repo Field String
    | UpdateRepoTimeout Org Repo Field Int
    | EnableRepos Repositories
    | DisableRepo Repository
    | ChownRepo Repository
    | RepairRepo Repository
    | RestartBuild Org Repo BuildNumber
      -- Inbound HTTP responses
    | UserResponse (Result (Http.Detailed.Error String) ( Http.Metadata, User ))
    | CurrentUserResponse (Result (Http.Detailed.Error String) ( Http.Metadata, CurrentUser ))
    | RepoResponse (Result (Http.Detailed.Error String) ( Http.Metadata, Repository ))
    | SourceRepositoriesResponse (Result (Http.Detailed.Error String) ( Http.Metadata, SourceRepositories ))
    | RepoFavoritedResponse String Bool (Result (Http.Detailed.Error String) ( Http.Metadata, CurrentUser ))
    | HooksResponse Org Repo (Result (Http.Detailed.Error String) ( Http.Metadata, Hooks ))
    | RepoEnabledResponse Repository (Result (Http.Detailed.Error String) ( Http.Metadata, Repository ))
    | RepoUpdatedResponse Field (Result (Http.Detailed.Error String) ( Http.Metadata, Repository ))
    | RepoDisabledResponse Repository (Result (Http.Detailed.Error String) ( Http.Metadata, String ))
    | RepoChownedResponse Repository (Result (Http.Detailed.Error String) ( Http.Metadata, String ))
    | RepoRepairedResponse Repository (Result (Http.Detailed.Error String) ( Http.Metadata, String ))
    | RestartedBuildResponse Org Repo BuildNumber (Result (Http.Detailed.Error String) ( Http.Metadata, Build ))
    | BuildResponse Org Repo BuildNumber (Result (Http.Detailed.Error String) ( Http.Metadata, Build ))
    | BuildsResponse Org Repo (Result (Http.Detailed.Error String) ( Http.Metadata, Builds ))
    | StepsResponse Org Repo BuildNumber (Maybe String) Bool (Result (Http.Detailed.Error String) ( Http.Metadata, Steps ))
    | StepResponse Org Repo BuildNumber StepNumber (Result (Http.Detailed.Error String) ( Http.Metadata, Step ))
    | SecretResponse (Result (Http.Detailed.Error String) ( Http.Metadata, Secret ))
    | SecretsResponse (Result (Http.Detailed.Error String) ( Http.Metadata, Secrets ))
      -- Other
    | HandleError Error
    | AlertsUpdate (Alerting.Msg Alert)
    | SessionChanged (Maybe Session)
    | FilterBuildEventBy (Maybe Event) Org Repo
    | FocusOn String
    | FocusResult (Result Dom.Error ())
    | OnKeyDown String
    | OnKeyUp String
    | VisibilityChanged Visibility
      -- Components
    | BuildUpdate Pages.Build.Model.Msg
    | PipelineUpdate Pages.Pipeline.Model.Msg
    | SecretsUpdate Engine Pages.Secrets.Model.Msg
      -- Time
    | AdjustTimeZone Zone
    | AdjustTime Posix
    | Tick Interval Posix
