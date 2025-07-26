/*
 * SPDX-License-Identifier: Apache-2.0
 */

const dayInSeconds = 24 * 60 * 60;

/**
 * Creates a build object with the provided properties.
 * @param {Object} props - The properties to include in the build object.
 * @param {number} props.enqueued - The timestamp when the build was enqueued.
 * @param {number} props.created - The timestamp when the build was created.
 * @param {number} props.started - The timestamp when the build was started.
 * @param {number} props.finished - The timestamp when the build was finished.
 * @param {string} props.status - The status of the build, defaulting to "success".
 * @param {number} [props.number=1] - The build number, defaulting to 1.
 * @returns {Object} The created build object.
 */
function createBuild({
  enqueued,
  created,
  started,
  finished,
  status = 'success',
  number = 1,
}) {
  return {
    id: number,
    repo_id: 1,
    number: number,
    parent: 1,
    event: 'push',
    status: status,
    error: '',
    enqueued: enqueued,
    created: created,
    started: started,
    finished: finished,
    deploy: '',
    link: `/github/octocat/${number}`,
    clone: 'https://github.com/github/octocat.git',
    source:
      'https://github.com/github/octocat/commit/9b1d8bded6e992ab660eaee527c5e3232d0a2441',
    title: 'push received from https://github.com/github/octocat',
    message: 'fixing docker params',
    commit: '9b1d8bded6e992ab660eaee527c5e3232d0a2441',
    sender: 'CookieCat',
    author: 'CookieCat',
    branch: 'infra',
    ref: 'refs/heads/infra',
    base_ref: '',
    host: '',
    runtime: 'docker',
    distribution: 'linux',
  };
}

/**
 * Returns the current Unix timestamp with an optional offset in seconds.
 * @param {number} [offsetSeconds=0] - The number of seconds to offset the timestamp by.
 * @returns {number} The current Unix timestamp plus the optional offset.
 */
function getUnixTime(offsetSeconds = 0) {
  return Math.floor(Date.now() / 1000) + offsetSeconds;
}

context('insights', () => {
  context('no builds', () => {
    beforeEach(() => {
      cy.intercept(
        { method: 'GET', url: '**/api/v1/repos/*/*/builds*' },
        { body: [] },
      );
      cy.login('/github/octocat/insights');
    });

    it('should show no builds message', () => {
      cy.get('[data-test=no-builds]').should('be.visible');
    });
  });

  context('varying builds', () => {
    beforeEach(() => {
      let builds = [];

      builds.push(
        createBuild({
          enqueued: getUnixTime(-3 * dayInSeconds),
          created: getUnixTime(-3 * dayInSeconds),
          started: getUnixTime(-3 * dayInSeconds),
          finished: getUnixTime(-3 * dayInSeconds + 30 * 60),
          status: 'success',
          number: 1,
        }),
      );

      builds.push(
        createBuild({
          enqueued: getUnixTime(-2 * dayInSeconds),
          created: getUnixTime(-2 * dayInSeconds),
          started: getUnixTime(-2 * dayInSeconds),
          finished: getUnixTime(-2 * dayInSeconds + 30 * 60),
          status: 'failure',
          number: 2,
        }),
      );

      builds.push(
        createBuild({
          enqueued: getUnixTime(-2 * dayInSeconds + 600),
          created: getUnixTime(-2 * dayInSeconds + 600),
          started: getUnixTime(-2 * dayInSeconds + 600),
          finished: getUnixTime(-2 * dayInSeconds + 600 + 15 * 60),
          status: 'success',
          number: 3,
        }),
      );

      builds.push(
        createBuild({
          enqueued: getUnixTime(-dayInSeconds),
          created: getUnixTime(-dayInSeconds),
          started: getUnixTime(-dayInSeconds),
          finished: getUnixTime(-dayInSeconds + 45 * 60),
          status: 'success',
          number: 4,
        }),
      );

      cy.intercept(
        { method: 'GET', url: '**/api/v1/repos/*/*/builds*' },
        { body: builds },
      );
      cy.login('/github/octocat/insights');
    });

    it('daily average should be 2', () => {
      cy.wait(3000); // Wait for metrics to calculate and render
      cy.get(
        '[data-test=metrics-quicklist-activity] > :nth-child(1) > .metric-value',
      ).should('have.text', '2');
    });

    it('average build time should be 30m 0s', () => {
      cy.wait(3000); // Wait for metrics to calculate and render
      cy.get(
        '[data-test=metrics-quicklist-duration] > :nth-child(1) > .metric-value',
      ).should('have.text', '30m 0s');
    });

    it('reliability should be 75% success', () => {
      cy.wait(3000); // Wait for metrics to calculate and render
      cy.get(
        '[data-test=metrics-quicklist-reliability] > :nth-child(1) > .metric-value',
      ).should('have.text', '75.0%');
    });

    it('time to recover should be 10 minutes', () => {
      cy.wait(3000); // Wait for metrics to calculate and render
      cy.get(
        '[data-test=metrics-quicklist-reliability] > :nth-child(3) > .metric-value',
      ).should('have.text', '10m 0s');
    });

    it('average queue time should be 0 seconds', () => {
      cy.wait(3000); // Wait for metrics to calculate and render
      cy.get(
        '[data-test=metrics-quicklist-queue] > :nth-child(1) > .metric-value',
      ).should('have.text', '0s');
    });
  });

  context('one identical build a day', () => {
    beforeEach(() => {
      const epochTime = getUnixTime(-6 * dayInSeconds);

      const builds = Array.from({ length: 7 }, (_, index) => {
        const created = epochTime + index * dayInSeconds;
        const enqueued = created + 10;
        const started = enqueued + 10;
        const finished = started + 30;

        return createBuild({
          enqueued,
          created,
          started,
          finished,
          number: index + 1,
        });
      });

      cy.intercept(
        { method: 'GET', url: '**/api/v1/repos/*/*/builds*' },
        { body: builds },
      );
      cy.login('/github/octocat/insights');
    });

    it('should show 4 metric quicklists', () => {
      cy.wait(3000); // Wait for metrics to calculate and render
      cy.get('[data-test^=metrics-quicklist-]').should('have.length', 4);
    });

    it('should show 4 charts', () => {
      cy.wait(3000); // Wait for charts to render
      cy.get('[data-test=metrics-chart]').should('have.length', 4);
    });

    it('daily average should be 1', () => {
      cy.wait(3000); // Wait for metrics to calculate and render
      cy.get(
        '[data-test=metrics-quicklist-activity] > :nth-child(1) > .metric-value',
      ).should('have.text', '1');
    });

    it('average build time should be 30 seconds', () => {
      cy.wait(3000); // Wait for metrics to calculate and render
      cy.get(
        '[data-test=metrics-quicklist-duration] > :nth-child(1) > .metric-value',
      ).should('have.text', '30s');
    });

    it('reliability should be 100% success', () => {
      cy.wait(3000); // Wait for metrics to calculate and render
      cy.get(
        '[data-test=metrics-quicklist-reliability] > :nth-child(1) > .metric-value',
      ).should('have.text', '100.0%');
    });

    it('average queue time should be 10 seconds', () => {
      cy.wait(3000); // Wait for metrics to calculate and render
      cy.get(
        '[data-test=metrics-quicklist-queue] > :nth-child(1) > .metric-value',
      ).should('have.text', '10s');
    });
  });
});
