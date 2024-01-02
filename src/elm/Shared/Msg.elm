module Shared.Msg exposing (Msg(..))

import Vela exposing (Org, Repo)


type Msg
    = -- NoOp
      NoOp
      -- -- User events
      --   NewRoute Routes.Route
      --     | ClickedLink UrlRequest
      --     | SearchSourceRepos Org String
    | ActualSharedMsg
    | SearchFavorites String
    | ToggleFavorite Org (Maybe Repo)



--     | ChangeRepoLimit String
--     | ChangeRepoTimeout String
--     | ChangeRepoCounter String
--     | RefreshSettings Org Repo
--     | RefreshHooks Org Repo
--     | RefreshSecrets Engine SecretType Org Repo
--     | FilterBuildEventBy (Maybe Event) Org Repo
--     | ShowHideFullTimestamp
--     | SetTheme Theme
--     | GotoPage Pagination.Page
--     | ShowHideHelp (Maybe Bool)
--     | ShowHideBuildMenu (Maybe Int) (Maybe Bool)
--     | ShowHideIdentity (Maybe Bool)
--     | Copy String
--     | DownloadFile String (String -> String) String String
--     | ExpandAllSteps Org Repo BuildNumber
--     | CollapseAllSteps
--     | ExpandStep Org Repo BuildNumber StepNumber
--     | FollowStep Int
--     | ExpandAllServices Org Repo BuildNumber
--     | CollapseAllServices
--     | ExpandService Org Repo BuildNumber ServiceNumber
--     | FollowService Int
--     | ShowHideTemplates
--     | FocusPipelineConfigLineNumber Int
--     | BuildGraphShowServices Bool
--     | BuildGraphShowSteps Bool
--     | BuildGraphRefresh Org Repo BuildNumber
--     | BuildGraphRotate
--     | BuildGraphUpdateFilter String
--     | OnBuildGraphInteraction GraphInteraction
--       -- Outgoing HTTP requests
--     | RefreshAccessToken
--     | SignInRequested
--     | FetchSourceRepositories
--     | ToggleFavorite Org (Maybe Repo)
--     | AddFavorite Org (Maybe Repo)
--     | EnableRepos Repositories
--     | EnableRepo Repository
--     | DisableRepo Repository
--     | ChownRepo Repository
--     | RepairRepo Repository
--     | UpdateRepoEvent Org Repo Field Bool
--     | UpdateRepoAccess Org Repo Field String
--     | UpdateRepoForkPolicy Org Repo Field String
--     | UpdateRepoPipelineType Org Repo Field String
--     | UpdateRepoLimit Org Repo Field Int
--     | UpdateRepoTimeout Org Repo Field Int
--     | UpdateRepoCounter Org Repo Field Int
--     | ApproveBuild Org Repo BuildNumber
--     | RestartBuild Org Repo BuildNumber
--     | CancelBuild Org Repo BuildNumber
--     | RedeliverHook Org Repo HookNumber
--     | GetPipelineConfig Org Repo BuildNumber Ref FocusFragment Bool
--     | ExpandPipelineConfig Org Repo BuildNumber Ref FocusFragment Bool
--       -- Inbound HTTP responses
--     | LogoutResponse (Result (Http.Detailed.Error String) ( Http.Metadata, String ))
--     | TokenResponse (Result (Http.Detailed.Error String) ( Http.Metadata, JwtAccessToken ))
--     | CurrentUserResponse (Result (Http.Detailed.Error String) ( Http.Metadata, CurrentUser ))
--     | SourceRepositoriesResponse (Result (Http.Detailed.Error String) ( Http.Metadata, SourceRepositories ))
--     | RepoFavoritedResponse String Bool (Result (Http.Detailed.Error String) ( Http.Metadata, CurrentUser ))
--     | RepoResponse (Result (Http.Detailed.Error String) ( Http.Metadata, Repository ))
--     | OrgRepositoriesResponse (Result (Http.Detailed.Error String) ( Http.Metadata, List Repository ))
--     | RepoEnabledResponse Repository (Result (Http.Detailed.Error String) ( Http.Metadata, Repository ))
--     | RepoDisabledResponse Repository (Result (Http.Detailed.Error String) ( Http.Metadata, String ))
--     | RepoUpdatedResponse Field (Result (Http.Detailed.Error String) ( Http.Metadata, Repository ))
--     | RepoChownedResponse Repository (Result (Http.Detailed.Error String) ( Http.Metadata, String ))
--     | RepoRepairedResponse Repository (Result (Http.Detailed.Error String) ( Http.Metadata, String ))
--     | ApprovedBuildResponse Org Repo BuildNumber (Result (Http.Detailed.Error String) ( Http.Metadata, String ))
--     | RestartedBuildResponse Org Repo BuildNumber (Result (Http.Detailed.Error String) ( Http.Metadata, Build ))
--     | CancelBuildResponse Org Repo BuildNumber (Result (Http.Detailed.Error String) ( Http.Metadata, Build ))
--     | OrgBuildsResponse Org (Result (Http.Detailed.Error String) ( Http.Metadata, Builds ))
--     | BuildsResponse Org Repo (Result (Http.Detailed.Error String) ( Http.Metadata, Builds ))
--     | DeploymentsResponse Org Repo (Result (Http.Detailed.Error String) ( Http.Metadata, List Deployment ))
--     | HooksResponse (Result (Http.Detailed.Error String) ( Http.Metadata, Hooks ))
--     | RedeliverHookResponse Org Repo HookNumber (Result (Http.Detailed.Error String) ( Http.Metadata, String ))
--     | BuildResponse Org Repo (Result (Http.Detailed.Error String) ( Http.Metadata, Build ))
--     | BuildAndPipelineResponse Org Repo (Maybe ExpandTemplatesQuery) (Result (Http.Detailed.Error String) ( Http.Metadata, Build ))
--     | DeploymentResponse (Result (Http.Detailed.Error String) ( Http.Metadata, Deployment ))
--     | StepsResponse Org Repo BuildNumber FocusFragment Bool (Result (Http.Detailed.Error String) ( Http.Metadata, Steps ))
--     | StepLogResponse StepNumber FocusFragment Bool (Result (Http.Detailed.Error String) ( Http.Metadata, Log ))
--     | ServicesResponse Org Repo BuildNumber (Maybe String) Bool (Result (Http.Detailed.Error String) ( Http.Metadata, Services ))
--     | ServiceLogResponse ServiceNumber FocusFragment Bool (Result (Http.Detailed.Error String) ( Http.Metadata, Log ))
--     | GetPipelineConfigResponse FocusFragment Bool (Result (Http.Detailed.Error String) ( Http.Metadata, PipelineConfig ))
--     | ExpandPipelineConfigResponse FocusFragment Bool (Result (Http.Detailed.Error String) ( Http.Metadata, String ))
--     | GetPipelineTemplatesResponse FocusFragment Bool (Result (Http.Detailed.Error String) ( Http.Metadata, Templates ))
--     | SecretResponse (Result (Http.Detailed.Error String) ( Http.Metadata, Secret ))
--     | AddSecretResponse (Result (Http.Detailed.Error String) ( Http.Metadata, Secret ))
--     | AddDeploymentResponse (Result (Http.Detailed.Error String) ( Http.Metadata, Deployment ))
--     | UpdateSecretResponse (Result (Http.Detailed.Error String) ( Http.Metadata, Secret ))
--     | RepoSecretsResponse (Result (Http.Detailed.Error String) ( Http.Metadata, Secrets ))
--     | OrgSecretsResponse (Result (Http.Detailed.Error String) ( Http.Metadata, Secrets ))
--     | SharedSecretsResponse (Result (Http.Detailed.Error String) ( Http.Metadata, Secrets ))
--     | DeleteSecretResponse (Result (Http.Detailed.Error String) ( Http.Metadata, String ))
--       -- Schedules
--     | SchedulesResponse Org Repo (Result (Http.Detailed.Error String) ( Http.Metadata, Schedules ))
--     | ScheduleResponse (Result (Http.Detailed.Error String) ( Http.Metadata, Schedule ))
--     | AddScheduleUpdate Pages.Schedules.Model.Msg
--     | AddScheduleResponse (Result (Http.Detailed.Error String) ( Http.Metadata, Schedule ))
--     | UpdateScheduleResponse (Result (Http.Detailed.Error String) ( Http.Metadata, Schedule ))
--     | DeleteScheduleResponse (Result (Http.Detailed.Error String) ( Http.Metadata, String ))
--       -- Graph
--     | BuildGraphResponse Org Repo BuildNumber Bool (Result (Http.Detailed.Error String) ( Http.Metadata, BuildGraph ))
--       -- Time
--     | AdjustTimeZone Zone
--     | AdjustTime Posix
--     | Tick Interval Posix
--       -- Components
--     | SecretsUpdate Pages.Secrets.Model.Msg
--     | AddDeploymentUpdate Pages.Deployments.Model.Msg
--       -- Other
--     | HandleError Error
--     | AlertsUpdate (Alerting.Msg Alert)
--     | FocusOn String
--     | FocusResult (Result Dom.Error ())
--     | OnKeyDown String
--     | OnKeyUp String
--     | VisibilityChanged Visibility
--     | PushUrl String
