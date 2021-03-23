import React from 'react';
import { Icon } from "semantic-ui-react";

import './accessibility.scss';

export const accessibilityIcon = (accessibility) => {
  if (!accessibility) {
    return;
  }

  const accessibleNorth = accessibility.directions.includes('north');
  const accessibleSouth = accessibility.directions.includes('south');

  if (accessibility.advisories.length > 0) {
    return (
      <span className='accessible-icon'>
        <Icon.Group>
          <Icon name='accessible' color='blue' title='This station is accessible' />
          <Icon corner name='warning' color='red' title='Elevator advisories at this station' />
        </Icon.Group>
      </span>
    );
  }

  if (accessibleNorth && accessibleSouth) {
    return (
      <span className='accessible-icon'>
        <Icon name='accessible' color='blue' title='This station is accessible' />
      </span>
    );
  }
    
  if (accessibleNorth && !accessibleSouth) {
    return (
      <span className='accessible-icon'>
        <Icon.Group>
          <Icon name='accessible' color='blue' title='This station is partially accessible' />
          <Icon corner name='caret up' title='' />
        </Icon.Group>
      </span>
    );
  }

  if (!accessibleNorth && accessibleSouth) {
    return (
      <span className='accessible-icon'>
        <Icon.Group>
          <Icon name='accessible' color='blue' title='This station is partially accessible' />
          <Icon corner name='caret down' title='' />
        </Icon.Group>
      </span>
    );
  }
}