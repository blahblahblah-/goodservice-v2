import React from 'react';
import { Header, Modal, List, Icon, Divider } from 'semantic-ui-react';
import { withRouter } from 'react-router-dom';
import { Helmet } from "react-helmet";

import TrainBullet from './trainBullet';

import './twitterModal.scss';

class TwitterModal extends React.Component {
  handleOnClose = () => {
    const { history } = this.props;
    return history.push('/');
  };

  render() {
    return(
      <Modal basic
        open={this.props.open} onClose={this.handleOnClose}
        closeIcon dimmer="blurring" className="twitter-modal" closeOnDocumentClick closeOnDimmerClick>
        <Helmet>
          <title>Subway Now lite (formerly goodservice.io) - Twitter Feeds</title>
          <meta property="og:title" content="Subway Now lite (formerly goodservice.io) - About" />
          <meta name="twitter:title" content="Subway Now lite (formerly goodservice.io) - About" />
          <meta property="og:url" content="https://lite.subwaynow.app/about" />
          <meta name="twitter:url" content="https://lite.subwaynow.app/about" />
        </Helmet>
        <Modal.Header>
          Follow us on Twitter for Alerts <Icon name='twitter' color='blue' />
        </Modal.Header>
        <Modal.Content>
          <Modal.Description>
            <p>
              Follow our accounts on Twitter to get alerts for delays as they are detected.
            </p>
            <Divider inverted horizontal />
            <List divided relaxed>
              <List.Item>
                <List.Content floated='right'>
                  <a href='https://twitter.com/goodservice_io' target='_blank'>@goodservice_io</a>
                </List.Content>
                <List.Content>
                  <strong>
                    All Trains
                  </strong>
                </List.Content>
              </List.Item>
              <List.Item>
                <List.Content floated='right'>
                  <a href='https://twitter.com/goodservice_1' target='_blank'>@goodservice_1</a>
                </List.Content>
                <List.Content>
                  <TrainBullet id='1' name='1' color='#db2828' size="small" />
                </List.Content>
              </List.Item>
              <List.Item>
                <List.Content floated='right'>
                  <a href='https://twitter.com/goodservice_2' target='_blank'>@goodservice_2</a>
                </List.Content>
                <List.Content>
                  <TrainBullet id='2' name='2' color='#db2828' size="small" />
                </List.Content>
              </List.Item>
              <List.Item>
                <List.Content floated='right'>
                  <a href='https://twitter.com/goodservice_3' target='_blank'>@goodservice_3</a>
                </List.Content>
                <List.Content>
                  <TrainBullet id='3' name='3' color='#db2828' size="small" />
                </List.Content>
              </List.Item>
              <List.Item>
                <List.Content floated='right'>
                  <a href='https://twitter.com/goodservice_4' target='_blank'>@goodservice_4</a>
                </List.Content>
                <List.Content>
                  <TrainBullet id='4' name='4' color='#21ba45' size="small" />
                </List.Content>
              </List.Item>
              <List.Item>
                <List.Content floated='right'>
                  <a href='https://twitter.com/goodservice_5' target='_blank'>@goodservice_5</a>
                </List.Content>
                <List.Content>
                  <TrainBullet id='5' name='5' color='#21ba45' size="small" />
                </List.Content>
              </List.Item>
              <List.Item>
                <List.Content floated='right'>
                  <a href='https://twitter.com/goodservice_6' target='_blank'>@goodservice_6</a>
                </List.Content>
                <List.Content>
                  <TrainBullet id='6' name='6' color='#21ba45' size="small" /> <TrainBullet id='6X' name='6X' color='#21ba45' size="small" />
                </List.Content>
              </List.Item>
              <List.Item>
                <List.Content floated='right'>
                  <a href='https://twitter.com/goodservice_7' target='_blank'>@goodservice_7</a>
                </List.Content>
                <List.Content>
                  <TrainBullet id='7' name='7' color='#a333c8' size="small" /> <TrainBullet id='7X' name='7X' color='#a333c8' size="small" />
                </List.Content>
              </List.Item>
              <List.Item>
                <List.Content floated='right'>
                  <a href='https://twitter.com/goodservice_A' target='_blank'>@goodservice_A</a>
                </List.Content>
                <List.Content>
                  <TrainBullet id='A' name='A' color='#2185d0' size="small" /> <TrainBullet id='H' name='S' color='#767676' size="small" /> Rockaway Shuttle
                </List.Content>
              </List.Item>
              <List.Item>
                <List.Content floated='right'>
                  <a href='https://twitter.com/goodservice_B' target='_blank'>@goodservice_B</a>
                </List.Content>
                <List.Content>
                  <TrainBullet id='B' name='B' color='#f2711c' size="small" />
                </List.Content>
              </List.Item>
              <List.Item>
                <List.Content floated='right'>
                  <a href='https://twitter.com/goodservice_C' target='_blank'>@goodservice_C</a>
                </List.Content>
                <List.Content>
                  <TrainBullet id='C' name='C' color='#2185d0' size="small" />
                </List.Content>
              </List.Item>
              <List.Item>
                <List.Content floated='right'>
                  <a href='https://twitter.com/goodservice_D' target='_blank'>@goodservice_D</a>
                </List.Content>
                <List.Content>
                  <TrainBullet id='D' name='D' color='#f2711c' size="small" />
                </List.Content>
              </List.Item>
              <List.Item>
                <List.Content floated='right'>
                  <a href='https://twitter.com/goodservice_E' target='_blank'>@goodservice_E</a>
                </List.Content>
                <List.Content>
                  <TrainBullet id='E' name='E' color='#2185d0' size="small" />
                </List.Content>
              </List.Item>
              <List.Item>
                <List.Content floated='right'>
                  <a href='https://twitter.com/goodservice_F' target='_blank'>@goodservice_F</a>
                </List.Content>
                <List.Content>
                  <TrainBullet id='F' name='F' color='#f2711c' size="small" /> <TrainBullet id='FX' name='FX' color='#f2711c' size="small" />
                </List.Content>
              </List.Item>
              <List.Item>
                <List.Content floated='right'>
                  <a href='https://twitter.com/goodservice_G' target='_blank'>@goodservice_G</a>
                </List.Content>
                <List.Content>
                  <TrainBullet id='G' name='G' color='#b5cc18' size="small" />
                </List.Content>
              </List.Item>
              <List.Item>
                <List.Content floated='right'>
                  <a href='https://twitter.com/goodservice_J' target='_blank'>@goodservice_J</a>
                </List.Content>
                <List.Content>
                  <TrainBullet id='J' name='J' color='#a5673f' size="small" /> <TrainBullet id='Z' name='Z' color='#a5673f' size="small" />
                </List.Content>
              </List.Item>
              <List.Item>
                <List.Content floated='right'>
                  <a href='https://twitter.com/goodservice_L' target='_blank'>@goodservice_L</a>
                </List.Content>
                <List.Content>
                  <TrainBullet id='L' name='L' color='#A0A0A0' size="small" />
                </List.Content>
              </List.Item>
              <List.Item>
                <List.Content floated='right'>
                  <a href='https://twitter.com/goodservice_M' target='_blank'>@goodservice_M</a>
                </List.Content>
                <List.Content>
                  <TrainBullet id='M' name='M' color='#f2711c' size="small" />
                </List.Content>
              </List.Item>
              <List.Item>
                <List.Content floated='right'>
                  <a href='https://twitter.com/goodservice_N' target='_blank'>@goodservice_N</a>
                </List.Content>
                <List.Content>
                  <TrainBullet id='N' name='N' color='#fbbd08' textColor='#000000' size="small" />
                </List.Content>
              </List.Item>
              <List.Item>
                <List.Content floated='right'>
                  <a href='https://twitter.com/goodservice_Q' target='_blank'>@goodservice_Q</a>
                </List.Content>
                <List.Content>
                  <TrainBullet id='Q' name='Q' color='#fbbd08' textColor='#000000' size="small" />
                </List.Content>
              </List.Item>
              <List.Item>
                <List.Content floated='right'>
                  <a href='https://twitter.com/goodservice_R' target='_blank'>@goodservice_R</a>
                </List.Content>
                <List.Content>
                  <TrainBullet id='R' name='R' color='#fbbd08' textColor='#000000' size="small" />
                </List.Content>
              </List.Item>
              <List.Item>
                <List.Content floated='right'>
                  <a href='https://twitter.com/goodservice_W' target='_blank'>@goodservice_W</a>
                </List.Content>
                <List.Content>
                  <TrainBullet id='W' name='W' color='#fbbd08' textColor='#000000' size="small" />
                </List.Content>
              </List.Item>
            </List>
          </Modal.Description>
        </Modal.Content>
      </Modal>
    )
  }
}
export default withRouter(TwitterModal);