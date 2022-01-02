import React from 'react';
import { Input, List, Header, Icon } from "semantic-ui-react";
import { Link } from 'react-router-dom';
import * as turf from '../vendor/turf.js';

import TrainBullet from './trainBullet';
import { formatStation } from './utils';
import { accessibilityIcon } from './accessibility.jsx';

import Cross from 'images/cross-15.svg'
import './stationList.scss';

class StationList extends React.Component {
  constructor(props) {
    super(props);

    this.state = {
      query: '',
      nearbyStations: [],
    };
  }

  componentDidMount() {
    const { selectedStationId, stations } = this.props;

    if (!selectedStationId) {
      this.queryInput.focus();
    }

    if (navigator.geolocation) {
      navigator.geolocation.getCurrentPosition(e => {
        const options = {units: 'miles'};
        const geolocation = [e.coords.longitude, e.coords.latitude];
        const nearbyStations = stations.map((s) => {
          const stationLocation = turf.helpers.point([s.longitude, s.latitude]);
          s.distance = turf.distance(geolocation, stationLocation, options);
          return s;
        }).filter((s) => s.distance <= 1.0).sort((a, b) => a.distance - b.distance).slice(0, 5).map((s) => s.id);
        this.setState({ nearbyStations: nearbyStations});
      });
    }
  }

  handleQueryChange = (e, data) => {
    const query = data.value.replace(/[^0-9a-z]/gi, '').toUpperCase();
    this.setState({query: query})
  };

  handleQueryClear = (e) => {
    e.target.parentElement.children[0].value = '';
    this.setState({query: ''});
  };

  handleQueryKeyUp = (e) => {
    if (e.key === "Escape") {
      e.target.value = '';
      this.setState({query: ''});
    }
  };

  renderListItem(station) {
    const { trains, favStations } = this.props;
    const { nearbyStations } = this.state;
    return (
      <List.Item as={Link} key={station.id} className='results-list-item' to={`/stations/${station.id}`}>
        <List.Content floated='left'>
          <Header as='h5'>
            {
              favStations.has(station.id) &&
                <Icon name="pin" inverted color="grey" />
            }
            {
              nearbyStations.includes(station.id) &&
                <Icon name="location arrow" inverted color="grey" />
            }
            { formatStation(station.name) }
            {
              station.secondary_name &&
              <span className='secondary-name'>
                { station.secondary_name }
              </span>
            }
            {
              accessibilityIcon(station.accessibility)
            }
          </Header>
        </List.Content>
        <List.Content floated='right'>
          {
            Object.keys(station.routes).map((routeId) => {
              const directions = station.routes[routeId];
              const train = trains[routeId];
              return (
                <TrainBullet id={routeId} key={train.name} name={train.name} color={train.color}
                  textColor={train.text_color} size='small' key={train.id} directions={directions} />
              );
            })
          }
          {
            Object.keys(station.routes).length === 0 &&
            <img src={Cross} className='cross' />
          }
        </List.Content>
      </List.Item>
    );
  }

  render() {
    const { stations, favStations } = this.props;
    const { query, nearbyStations } = this.state;
    let selectedStations;
    if (query.length < 1) {
      selectedStations = stations;
    } else {
      selectedStations = stations.filter((station) =>
        station.name.replace(/[^0-9a-z]/gi, '').toUpperCase().indexOf(query) > -1 || station.secondary_name?.replace(/[^0-9a-z]/gi, '').toUpperCase().indexOf(query) > -1
      );
    }

    const icon = query.length < 1 ? 'search' : { name: 'close', link: true, onClick: this.handleQueryClear}

    return (
      <div className='station-list'>
        <Input icon={icon} placeholder='Search...' onChange={this.handleQueryChange} onKeyUp={this.handleQueryKeyUp} ref={(input) => { this.queryInput = input; }}  fluid className="station-search" />
        <List divided relaxed selection inverted className='results'>
          {
            selectedStations.filter((station) => favStations.has(station.id)).map((station) => {
              return this.renderListItem(station);
            })
          }
          {
            nearbyStations.filter((stationId) => !favStations.has(stationId)).map((stationId) => selectedStations.find((s) => s.id === stationId)).map((station) => {
              return this.renderListItem(station);
            })
          }
          {
            query.length < 1 &&
              selectedStations.filter((station) => !favStations.has(station.id) && !nearbyStations.includes(station.id)).map((station) => {
                return this.renderListItem(station);
              })
          }
          {
            query.length > 0 &&
              selectedStations.filter((station) => !favStations.has(station.id) && !nearbyStations.includes(station.id)).sort((a, b) => {
                const queryText = query.toUpperCase();
                const nameA = a.name.replace(/[^0-9a-z]/gi, '').toUpperCase();
                const nameB = b.name.replace(/[^0-9a-z]/gi, '').toUpperCase();

                if (nameA.includes(queryText) && !nameB.includes(queryText)) {
                  return -1
                }
                if (!nameA.includes(queryText) && nameB.includes(queryText)) {
                  return 1;
                }

                if (nameA < nameB) {
                  return -1;
                }
                if (nameA > nameB) {
                  return 1;
                }

                return 0;

              }).map((station) => {
                return this.renderListItem(station);
              })
          }
        </List>
      </div>
    );
  }
}

export default StationList;