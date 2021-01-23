import React from 'react';
import { Header } from 'semantic-ui-react';
import { Link } from "react-router-dom";

import TrainBullet from './trainBullet.jsx';
import { formatStation } from './utils';

import './trainMapStop.scss'

class TrainMapStop extends React.Component {

  renderStop() {
    const { southStop, northStop} = this.props;

    if (southStop && northStop) {
      return (
        <div className='both-stop'>
        </div>
      )
    }

    if (northStop) {
      return (
        <div className='north-stop'>
        </div>
      )
    }

    return (
      <div className='south-stop'>
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

  renderLine(isActiveBranch, index, branchStart, branchEnd) {
    const { color, branchStops, arrivalTime } = this.props;
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
          this.renderMainLine(background, margin, stopExists)
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

  render() {
    const { stop, transfers, trains, activeBranches, branchStart, branchEnd, arrivalTime } = this.props;
    const eta = arrivalTime && Math.round(arrivalTime / 60);
    return (
      <li className='train-map-stop'>
        <div className='container'>
          {
            arrivalTime &&
            <Header as='h6'
            style={{minWidth: "20px", maxWidth: "20px", margin: "auto 0 auto 10px", display: "inline", textAlign: "center"}} inverted>
              { eta > 0 &&
                <span title={new Date(Date.now() + arrivalTime * 1000).toLocaleTimeString([], { hour: 'numeric', minute: '2-digit'})}>{ eta } min</span>
              }
              { eta <= 0 &&
                <span>Due</span>
              }
            </Header>
          }
          {
            !arrivalTime &&
            <div className='left-margin'></div>
          }
          { activeBranches.map((obj, index) => {
              return this.renderLine(obj, index, branchStart, branchEnd);
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