import React from 'react';
import { Header } from 'semantic-ui-react';
import { Link } from "react-router-dom";

import TrainBullet from './trainBullet.jsx';
import { formatStation } from './utils';

import './trainMapStop.scss'

class TrainMapStop extends React.Component {

  renderStop() {
    const { southStop, northStop, train, trips } = this.props;

    const time = Date.now() / 1000;
    const stopsBefore = trips && trips.filter((t) => (t.estimated_upcoming_stop_arrival_time - time) > 60);
    const stopsAt = trips && trips.filter((t) => (t.estimated_upcoming_stop_arrival_time - time) <= 60);
    const tripContainer = [];

    if (stopsBefore && stopsBefore.length > 0) {
      tripContainer.push(
        <Link to={`/trains/${train.id}/${stopsBefore[0].id}`}>
          <div className='trip-before' key='trip-before'></div>
        </Link>
      );
    }

    if (stopsAt && stopsAt.length > 0) {
      tripContainer.push(
        <Link to={`/trains/${train.id}/${stopsAt[0].id}`}>
          <div className='trip-at' key='trip-at'></div>
        </Link>
      );
    }

    if (southStop && northStop) {
      return (
        <div className='both-stop'>
          { tripContainer }
        </div>
      )
    }

    if (northStop) {
      return (
        <div className='north-stop'>
          { tripContainer }
        </div>
      )
    }

    return (
      <div className='south-stop'>
        { tripContainer }
      </div>
    )
  }

  renderMainLine(background, margin, stopExists) {
    return (
      <div style={{margin: margin, height: "100%", minHeight: "50px", minWidth: "20px", background: background, display: "inline-block"}}>
        {
          stopExists && this.renderStop()
        }
      </div>
    )
  }

  renderLine(isActiveBranch, index, branchStart, branchEnd, trips) {
    const { branchStops, arrivalTime, train } = this.props;
    const color = train.color;
    const stopExists = branchStops[index];
    const branchStartHere = branchStart !== null && branchStart == index;
    const branchEndHere = branchEnd !== null && branchEnd == index;
    const marginValue = "20px";
    const branching = branchStartHere || branchEndHere;
    const margin = branching ? ("0 0 0 " + marginValue) : (arrivalTime ? ("0 10px") : ("0 " + marginValue));
    let background;

    if (stopExists) {
      let topStripeColor;
      let bottomStripeColor;
      let middleStripeColor;

      middleStripeColor = bottomStripeColor || topStripeColor || color;
      topStripeColor = topStripeColor || color;
      bottomStripeColor = bottomStripeColor || color;

      background = `repeating-linear-gradient(0deg, ${color}, ${color} 1px, ${middleStripeColor} 1px, ${middleStripeColor} 2px)`;
    } else {
      background = color;
    }

    if (!isActiveBranch) {
      return (
        <div key={index} style={{margin: margin, height: "100%", minHeight: "50px", minWidth: "20px", display: "inline-block"}}>
        </div>
      )
    }

    return (
      <div key={index} style={{minWidth: (branching ? "120px" : (arrivalTime ? "45px" : "60px")), display: "flex"}}>
        {
          this.renderMainLine(background, margin, stopExists, trips)
        }
        {
          branching &&
          <div style={{margin: "15px 0", height: "20px", width: marginValue, backgroundColor: color, display: "inline-block", alignSelf: "flex-start"}}>
          </div>
        }
        {
          branchStartHere &&
          <div style={{height: "100%"}} className="branch-corner">
            <div style={{boxShadow: "0 0 0 20px " + color, transform: "translate(-10px, 35px)"}} className="branch-start">
            </div>
          </div>
        }
        {
          branchEndHere &&
          <div style={{height: "50px"}} className="branch-corner">
            <div style={{boxShadow: "0 0 0 20px " + color, transform: "translate(-9px, -35px)"}} className="branch-end">
            </div>
          </div>
        }
      </div>
    )
  }

  renderTravelTime() {
    const { stopId, previousStopId, train } = this.props;
    if (!previousStopId || !stopId) {
      return;
    }
    const lookupString = `${previousStopId}-${stopId}`;
    const estimatedTravelTime = train.estimated_travel_times[lookupString];
    const scheduledTravelTime = train.scheduled_travel_times[lookupString];

    if (!estimatedTravelTime || !scheduledTravelTime) {
      return;
    }

    if (!estimatedTravelTime) {
      const roundedScheduledTime = Math.round(scheduledTravelTime / 60);
      return `${roundedScheduledTime} min`;
    }

    const roundedEstimatedTime = Math.round(estimatedTravelTime / 60);

    if (!scheduledTravelTime) {
      return `${roundedEstimatedTime} min`;
    }

    const diff = estimatedTravelTime - scheduledTravelTime;

    if (Math.abs(diff) >= 60) {
      const roundedDiff = Math.round(diff / 60);
      if (roundedDiff > 0) {
        return (
          <>
            <>
              {roundedEstimatedTime} min<br/>
            </>
            <span className='warning'>
              (+{roundedDiff} min)
            </span>
          </>
        );
      }
      return (
        <>
          <>
            {roundedEstimatedTime} min<br/>
          </>
          <>
            ({roundedDiff} min)
          </>
        </>
      );
    }
    return `${roundedEstimatedTime} min`;
  }

  render() {
    const { stop, transfers, trains, activeBranches, branchStart, branchEnd, showTravelTime, trips } = this.props;
    return (
      <li className='train-map-stop'>
        <div className='container'>
          {
            showTravelTime &&
            <Header as='h6' className='travel-time' inverted>
              { this.renderTravelTime() }
            </Header>
          }
          {
            !showTravelTime &&
            <div className='left-margin'></div>
          }
          { activeBranches.map((obj, index) => {
              return this.renderLine(obj, index, branchStart, branchEnd, trips);
            })
          }
          <Header as='h5' className='station-name' inverted>
            {
              formatStation(stop)
            }
          </Header>
          <div className='transfers'>
            {
              transfers && Object.keys(transfers).map((routeId) => {
                const directions = transfers[routeId];
                const train = trains[routeId];
                return (
                  <TrainBullet link={true} id={routeId} key={train.name} name={train.name} color={train.color}
                    textColor={train.text_color} size='small' directions={directions} />
                )
              })
            }
          </div>
        </div>
      </li>
    )
  }
}
export default TrainMapStop;