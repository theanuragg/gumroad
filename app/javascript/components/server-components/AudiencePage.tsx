import { lightFormat } from "date-fns";
import * as React from "react";
import { createCast } from "ts-safe-cast";

import { AudienceDataByDate, fetchAudienceDataByDate } from "$app/data/audience";
import { AbortError } from "$app/utils/request";
import { register } from "$app/utils/serverComponentUtil";

import { AnalyticsLayout } from "$app/components/Analytics/AnalyticsLayout";
import { useAnalyticsDateRange } from "$app/components/Analytics/useAnalyticsDateRange";
import { AudienceChart } from "$app/components/Audience/AudienceChart";
import { AudienceQuickStats } from "$app/components/Audience/AudienceQuickStats";
import { NavigationButton } from "$app/components/Button";
import { DateRangePicker } from "$app/components/DateRangePicker";
import { Icon } from "$app/components/Icons";
import { Progress } from "$app/components/Progress";
import { showAlert } from "$app/components/server-components/Alert";
import { WithTooltip } from "$app/components/WithTooltip";

import placeholder from "$assets/images/placeholders/audience.png";

const AudiencePage = ({ total_follower_count }: { total_follower_count: number }) => {
  const dateRange = useAnalyticsDateRange();
  const [data, setData] = React.useState<AudienceDataByDate | null>(null);
  const startTime = lightFormat(dateRange.from, "yyyy-MM-dd");
  const endTime = lightFormat(dateRange.to, "yyyy-MM-dd");

  const hasContent = total_follower_count > 0;

  const activeRequest = React.useRef<AbortController | null>(null);
  React.useEffect(() => {
    const loadData = async () => {
      if (!hasContent) return;

      try {
        if (activeRequest.current) activeRequest.current.abort();
        setData(null);
        const request = fetchAudienceDataByDate({ startTime, endTime });
        activeRequest.current = request.abort;
        setData(await request.response);
        activeRequest.current = null;
      } catch (e) {
        if (e instanceof AbortError) return;
        showAlert("Sorry, something went wrong. Please try again.", "error");
      }
    };
    void loadData();
  }, [startTime, endTime]);

  return (
    <AnalyticsLayout
      selectedTab="following"
      actions={
        hasContent ? (
          <>
            <WithTooltip tip="Export">
              <NavigationButton href={Routes.audience_export_path({ format: "csv" })}>
                <Icon name="download" />
              </NavigationButton>
            </WithTooltip>
            <DateRangePicker {...dateRange} />
          </>
        ) : null
      }
    >
      {hasContent ? (
        <div style={{ display: "grid", gap: "var(--spacer-7)" }}>
          <AudienceQuickStats totalFollowers={total_follower_count} newFollowers={data?.new_followers ?? null} />
          {data ? (
            <AudienceChart data={data} />
          ) : (
            <div className="input">
              <Progress width="1em" />
              Loading charts...
            </div>
          )}
        </div>
      ) : (
        <div>
          <div className="placeholder">
            <figure>
              <img src={placeholder} />
            </figure>
            <h2>It's quiet. Too quiet.</h2>
            <p>
              You don't have any followers yet. Once you do, you'll see them here, along with powerful data that can
              help you keep your growing audience engaged.
            </p>
            <a href="#" data-helper-prompt="How are followers different from customers?">
              Learn more
            </a>
          </div>
        </div>
      )}
    </AnalyticsLayout>
  );
};

export default register({ component: AudiencePage, propParser: createCast() });
